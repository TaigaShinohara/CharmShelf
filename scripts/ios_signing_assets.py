"""Temporary macOS signing keychain; passwords go only through security stdin."""
import base64,json,hashlib,os,re,secrets,shlex,stat,subprocess,sys,tempfile
from pathlib import Path
from check_ios_signing import validate

class SigningError(Exception):pass

PROFILE_DIRECTORIES = {
    'mobiledevice': Path('Library/MobileDevice/Provisioning Profiles'),
    'xcode': Path('Library/Developer/Xcode/UserData/Provisioning Profiles'),
}
PROFILE_UUID = re.compile(r'[A-Fa-f0-9]{8}(?:-[A-Fa-f0-9]{4}){3}-[A-Fa-f0-9]{12}')

def profile_directories():
    home = Path.home()
    return {name: home / relative for name, relative in PROFILE_DIRECTORIES.items()}

def check_profile_directory(directory):
    # Never follow a substituted directory into an unrelated profile store.
    for path in (directory, *directory.parents):
        if path == Path.home():break
        if path.is_symlink() or (path.exists() and not path.is_dir()):
            raise SigningError('UNSAFE_PROFILE_DIRECTORY')

def created_profiles(state):
    if not isinstance(state,dict):raise SigningError('INVALID_SIGNING_STATE')
    uuid = state.get('profile_uuid')
    if not isinstance(uuid,str) or not PROFILE_UUID.fullmatch(uuid):
        raise SigningError('INVALID_PROFILE_UUID')
    # The old shared boolean cannot establish which directory we created.
    # Preserve all profiles for legacy state instead of guessing ownership.
    if state.get('state_version') != 2:return []
    ledger = state.get('created_profiles')
    if not isinstance(ledger,list):raise SigningError('INVALID_SIGNING_STATE')
    checksum = state.get('profile_sha256')
    if not isinstance(checksum,str) or not re.fullmatch('[a-f0-9]{64}',checksum):
        raise SigningError('INVALID_SIGNING_STATE')
    paths = profile_directories()
    found = set()
    profiles = []
    for entry in ledger:
        if not isinstance(entry,dict):raise SigningError('INVALID_SIGNING_STATE')
        location = entry.get('location')
        if not isinstance(location,str) or location not in paths or location in found:
            raise SigningError('INVALID_SIGNING_STATE')
        if any(type(entry.get(key)) is not int or entry[key] < 0 for key in ('device','inode')):
            raise SigningError('INVALID_SIGNING_STATE')
        found.add(location)
        profiles.append((paths[location] / (uuid+'.mobileprovision'),entry))
    return profiles

def security(arguments):
    # security's interactive parser accepts quoted arguments; reject command boundaries.
    if any(any(c in str(a) for c in '\r\n\0') for a in arguments):
        raise SigningError('INVALID_SECURITY_ARGUMENT')
    command=' '.join('"'+str(a).replace('\\','\\\\').replace('"','\\"')+'"' for a in arguments)+'\n'
    result=subprocess.run(['/usr/bin/security','-i'],input=command,capture_output=True,text=True,timeout=30)
    if result.returncode:raise SigningError('KEYCHAIN_OPERATION_FAILED')
    return result.stdout

def remove_private_staging(staging,identity):
    try:current=staging.lstat()
    except FileNotFoundError:return
    if identity is None or not stat.S_ISREG(current.st_mode) or (current.st_dev,current.st_ino)!=(identity.st_dev,identity.st_ino):
        raise SigningError('SIGNING_STAGING_CHANGED')
    staging.unlink()

def rollback_private_publish(path,identity,content):
    try:
        current=path.lstat()
        if not stat.S_ISREG(current.st_mode) or (current.st_dev,current.st_ino)!=(identity.st_dev,identity.st_ino):return
        # Never follow a concurrently substituted symlink or read a different
        # inode. Changed content is also retained, as in profile ownership cleanup.
        fd=os.open(path,os.O_RDONLY|os.O_NOFOLLOW)
        with os.fdopen(fd,'rb') as stream:
            opened=os.fstat(stream.fileno())
            if (opened.st_dev,opened.st_ino)!=(identity.st_dev,identity.st_ino):return
            if stream.read()!=content:return
            verified=os.fstat(stream.fileno())
        current=path.lstat()
        if stat.S_ISREG(current.st_mode) and (current.st_dev,current.st_ino,current.st_size,current.st_mtime_ns)==(verified.st_dev,verified.st_ino,verified.st_size,verified.st_mtime_ns):
            path.unlink()
    except FileNotFoundError:return

def private_write(path,content):
    path=Path(path)
    fd,temporary=tempfile.mkstemp(prefix='.'+path.name+'.',suffix='.partial',dir=path.parent)
    staging=Path(temporary)
    identity=None
    published=False
    try:
        identity=os.fstat(fd)
        os.fchmod(fd,0o600)
        stream=os.fdopen(fd,'wb')
        fd=None  # The stream owns the descriptor, including on a write failure.
        with stream:
            if stream.write(content)!=len(content):raise SigningError('INCOMPLETE_SIGNING_WRITE')
            stream.flush()
            os.fsync(stream.fileno())
            identity=os.fstat(stream.fileno())
        # Publish only after the stream also closes successfully. A hard link
        # creates the destination atomically and refuses an existing file or
        # symlink, including one created after the preparation preflight.
        current=staging.lstat()
        if not stat.S_ISREG(current.st_mode) or (current.st_dev,current.st_ino)!=(identity.st_dev,identity.st_ino):
            raise SigningError('SIGNING_STAGING_CHANGED')
        os.link(staging,path,follow_symlinks=False)
        published=True
        return identity
    finally:
        if fd is not None:os.close(fd)
        try:remove_private_staging(staging,identity)
        except BaseException:
            try:
                # The caller has not yet registered ownership. An exception
                # after publication must not leave our destination untracked.
                if published:rollback_private_publish(path,identity,content)
            finally:
                # A transient unlink failure can leave the private staging
                # link. Retry its guarded cleanup once, preserving the failure.
                try:remove_private_staging(staging,identity)
                except (OSError,SigningError):pass
            raise

def search_list():
    return shlex.split(security(['list-keychains','-d','user']))

def clean(folder,*,prepared_state=None):
    folder=Path(folder)
    if folder.is_symlink():raise SigningError('UNSAFE_SIGNING_DIRECTORY')
    statefile=folder/'state.json'
    if statefile.is_symlink():raise SigningError('UNSAFE_SIGNING_STATE')
    if not statefile.exists():return
    state=prepared_state if prepared_state is not None else json.loads(statefile.read_text())
    profiles=created_profiles(state)
    keychain=folder/'build.keychain-db'
    if keychain.is_symlink():raise SigningError('UNSAFE_SIGNING_KEYCHAIN')
    if state.get('keychain_attempted'):
        if keychain.exists():
            current=search_list()
            if str(keychain) in current:security(['list-keychains','-d','user','-s',*[p for p in current if p!=str(keychain)]])
            security(['delete-keychain',str(keychain)])
    owned=[]
    for profile,entry in profiles:
        check_profile_directory(profile.parent)
        if profile.is_symlink():raise SigningError('PROFILE_CHANGED_DURING_SIGNING')
        if profile.exists():
            identity=profile.stat()
            if (identity.st_dev,identity.st_ino)!=(entry['device'],entry['inode']):
                raise SigningError('PROFILE_CHANGED_DURING_SIGNING')
            if hashlib.sha256(profile.read_bytes()).hexdigest()!=state['profile_sha256']:
                raise SigningError('PROFILE_CHANGED_DURING_SIGNING')
            owned.append(profile)
    for profile in owned:profile.unlink()
    for name in ('certificate.p12','state.json'):(folder/name).unlink(missing_ok=True)
    folder.rmdir()

def prepare(folder,environment):
    metadata,p12,profile=validate(environment)
    if not PROFILE_UUID.fullmatch(metadata['profile_uuid']):raise SigningError('INVALID_PROFILE_UUID')
    locations=profile_directories()
    # Inspect both stores before creating a keychain or any signing material.
    for profiles in locations.values():
        check_profile_directory(profiles)
        destination=profiles/(metadata['profile_uuid']+'.mobileprovision')
        if destination.is_symlink() or (destination.exists() and destination.read_bytes()!=profile):
            raise SigningError('EXISTING_PROFILE_DIFFERS')
    folder=Path(folder);folder.mkdir(mode=0o700)
    state={'state_version':2,'profile_uuid':metadata['profile_uuid'],'profile_sha256':hashlib.sha256(profile).hexdigest(),'created_profiles':[],'keychain_attempted':False}
    statefile=folder/'state.json'
    private_write(statefile,(json.dumps(state)+'\n').encode())
    def save():statefile.write_text(json.dumps(state)+'\n')
    try:
        original=search_list()
        certificate=folder/'certificate.p12';private_write(certificate,p12)
        keychain=folder/'build.keychain-db';password=secrets.token_urlsafe(36)
        state['keychain_attempted']=True;save()
        security(['create-keychain','-p',password,str(keychain)])
        security(['set-keychain-settings','-lut','21600',str(keychain)])
        security(['unlock-keychain','-p',password,str(keychain)])
        security(['import',str(certificate),'-k',str(keychain),'-P',environment['IOS_CERTIFICATE_PASSWORD'],'-T','/usr/bin/codesign','-T','/usr/bin/security'])
        security(['set-key-partition-list','-S','apple-tool:,apple:','-s','-k',password,str(keychain)])
        security(['list-keychains','-d','user','-s',str(keychain),*original])
        identities=security(['find-identity','-v','-p','codesigning',str(keychain)])
        if metadata['identity_sha1'] not in identities:raise SigningError('IMPORTED_IDENTITY_NOT_FOUND')
        
        # Xcode 16/26以降、およびそれ以前の両方のパスにプロファイルを配置する。
        for location,profiles in locations.items():
            check_profile_directory(profiles)
            profiles.mkdir(parents=True,exist_ok=True)
            destination=profiles/(metadata['profile_uuid']+'.mobileprovision')
            if destination.exists() or destination.is_symlink():
                if destination.is_symlink() or destination.read_bytes()!=profile:raise SigningError('EXISTING_PROFILE_DIFFERS')
            else:
                identity=private_write(destination,profile)
                state['created_profiles'].append({'location':location,'device':identity.st_dev,'inode':identity.st_ino})
                save()

        certificate.unlink()
        return {'IOS_PROVISIONING_PROFILE_UUID':metadata['profile_uuid'],'IOS_BUNDLE_ID':metadata['bundle_id'],'APPLE_TEAM_ID':metadata['team_id'],'CODEX_IOS_KEYCHAIN_PATH':str(keychain),'CODEX_IOS_IDENTITY_SHA1':metadata['identity_sha1']}
    except BaseException:
        clean(folder,prepared_state=state)
        raise

def ci_main():
    root=Path(os.environ['RUNNER_TEMP'])
    if not root.is_absolute() or not root.is_dir():raise SigningError('INVALID_RUNNER_TEMP')
    folder=root/'codex-ios-signing'
    if sys.argv[1:]==['--clean']:clean(folder);return
    if sys.argv[1:]:raise SigningError('INVALID_ARGUMENT')
    child=prepare(folder,os.environ)
    try:
        if any(any(c in value for c in '\r\n') for value in child.values()):raise SigningError('INVALID_METADATA')
        with open(os.environ['GITHUB_ENV'],'a') as stream:
            for name,value in child.items():stream.write(name+'='+value+'\n')
    except BaseException:
        clean(folder);raise

if __name__=='__main__':
    try:ci_main()
    except Exception:raise SystemExit('IOS_SIGNING_SETUP_FAILED: Check profile, certificate, permissions and expiry.') from None
