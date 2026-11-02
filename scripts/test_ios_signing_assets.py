import hashlib,itertools,json,stat,tempfile,unittest
from contextlib import contextmanager
from pathlib import Path
from unittest.mock import patch
from types import SimpleNamespace
import ios_signing_assets as signing

class SigningTests(unittest.TestCase):
    def test_password_only_goes_to_stdin(self):
        with patch.object(signing.subprocess,'run',return_value=SimpleNamespace(returncode=0,stdout='',stderr='')) as run:
            signing.security(['unlock-keychain','-p','dummy-password','/tmp/a b'])
            self.assertEqual(run.call_args.args[0],['/usr/bin/security','-i'])
            self.assertNotIn('dummy-password',str(run.call_args.args))
            self.assertIn('dummy-password',run.call_args.kwargs['input'])
            self.assertTrue(run.call_args.kwargs['capture_output'])
    def test_command_boundary_rejected(self):
        with patch.object(signing.subprocess,'run') as run:
            with self.assertRaises(signing.SigningError):signing.security(['help\nother'])
            run.assert_not_called()
    def test_private_file_does_not_overwrite(self):
        with tempfile.TemporaryDirectory() as root:
            file=Path(root)/'p';signing.private_write(file,b'dummy')
            self.assertEqual(stat.S_IMODE(file.stat().st_mode),0o600)
            with self.assertRaises(FileExistsError):signing.private_write(file,b'replaced')
            self.assertEqual(file.read_bytes(),b'dummy')
    def exercise(self,*,fail_import=False,existing_profile=False,conflicting_profile=False):
        with tempfile.TemporaryDirectory() as root:
            home=Path(root);folder=home/'assets';profile_dir=home/'Library/Developer/Xcode/UserData/Provisioning Profiles';profile_dir.mkdir(parents=True)
            uuid='00000000-0000-0000-0000-000000000000';profile=profile_dir/(uuid+'.mobileprovision')
            if existing_profile:profile.write_bytes(b'other' if conflicting_profile else b'dummy-profile')
            metadata={'profile_uuid':uuid,'identity_sha1':'ABCDEF','bundle_id':'example.test','team_id':'TEST'}
            commands=[]
            def security(args):
                commands.append(args)
                if args[0]=='list-keychains':return '"/tmp/original.keychain-db"\n'
                if args[0]=='create-keychain':Path(args[-1]).touch()
                if args[0]=='delete-keychain':Path(args[-1]).unlink()
                if args[0]=='import' and fail_import:raise signing.SigningError('IMPORT_FAILED')
                if args[0]=='find-identity':return 'ABCDEF'
                return ''
            with patch.object(Path,'home',return_value=home),patch.object(signing,'security',side_effect=security),patch.object(signing,'validate',return_value=(metadata,b'dummy-p12',b'dummy-profile')):
                if fail_import or conflicting_profile:
                    with self.assertRaises(signing.SigningError):signing.prepare(folder,{'IOS_CERTIFICATE_PASSWORD':'dummy-password'})
                else:
                    result=signing.prepare(folder,{'IOS_CERTIFICATE_PASSWORD':'dummy-password'})
                    self.assertNotIn('dummy-password',json.dumps(result))
                    self.assertFalse((folder/'certificate.p12').exists())
                    signing.clean(folder)
                self.assertFalse(folder.exists())
                self.assertEqual(profile.exists(),existing_profile)
                if existing_profile:self.assertEqual(profile.read_bytes(),b'other' if conflicting_profile else b'dummy-profile')
                if conflicting_profile:self.assertEqual(commands,[])
                else:self.assertTrue(any(c[0]=='delete-keychain' for c in commands))
    def test_success_cleans_only_temporary_material(self):self.exercise()
    def test_import_failure_cleans_partial_setup(self):self.exercise(fail_import=True)
    def test_existing_identical_profile_preserved(self):self.exercise(existing_profile=True)
    def test_conflicting_profile_preserved_and_stops(self):self.exercise(existing_profile=True,conflicting_profile=True)
    def test_cleanup_refuses_symlink(self):
        with tempfile.TemporaryDirectory() as root:
            f=Path(root)/'alias';f.symlink_to(root)
            with self.assertRaises(signing.SigningError):signing.clean(f)

    def test_private_write_preserves_existing_destination_and_symlink(self):
        with tempfile.TemporaryDirectory() as root:
            directory=Path(root)
            existing=directory/'existing';existing.write_bytes(b'preserve')
            linked=directory/'linked';linked.symlink_to(existing)
            for destination in (existing,linked):
                with self.subTest(destination=destination.name):
                    with self.assertRaises(FileExistsError):signing.private_write(destination,b'synthetic-new')
                    self.assertEqual(existing.read_bytes(),b'preserve')
                    self.assertEqual(list(directory.glob('.*.partial')),[])
            self.assertTrue(linked.is_symlink())

    def test_private_write_publishes_complete_private_file_and_returns_its_inode(self):
        with tempfile.TemporaryDirectory() as root:
            destination=Path(root)/'private'
            identity=signing.private_write(destination,b'synthetic-complete')
            actual=destination.stat()
            self.assertEqual(destination.read_bytes(),b'synthetic-complete')
            self.assertEqual(stat.S_IMODE(actual.st_mode),0o600)
            self.assertEqual((identity.st_dev,identity.st_ino),(actual.st_dev,actual.st_ino))
            self.assertEqual(list(destination.parent.glob('.*.partial')),[])

    def test_private_write_rejects_a_short_write_without_publishing(self):
        original_fdopen=signing.os.fdopen
        class ShortStream:
            def __init__(self,stream):self.stream=stream
            def __enter__(self):return self
            def __exit__(self,*args):return self.stream.__exit__(*args)
            def write(self,content):
                self.stream.write(content[:3]);self.stream.flush()
                return 3
        with tempfile.TemporaryDirectory() as root:
            destination=Path(root)/'private'
            with patch.object(signing.os,'fdopen',side_effect=lambda *a,**kw:ShortStream(original_fdopen(*a,**kw))):
                with self.assertRaisesRegex(signing.SigningError,'INCOMPLETE_SIGNING_WRITE'):
                    signing.private_write(destination,b'synthetic-complete')
            self.assertFalse(destination.exists())
            self.assertEqual(list(destination.parent.glob('.*.partial')),[])
            signing.private_write(destination,b'synthetic-complete')
            self.assertEqual(destination.read_bytes(),b'synthetic-complete')

class ProfileOwnershipTests(unittest.TestCase):
    uuid='00000000-0000-0000-0000-000000000000'
    profile=b'dummy-profile'

    @contextmanager
    def fixture(self,initial=('absent','absent'),*,fail_import=False,race_at=None):
        with tempfile.TemporaryDirectory() as root:
            home=Path(root);folder=home/'assets';commands=[]
            profiles=[home/relative/(self.uuid+'.mobileprovision') for relative in signing.PROFILE_DIRECTORIES.values()]
            expected={}
            for path,value in zip(profiles,initial):
                path.parent.mkdir(parents=True)
                if value!='absent':
                    expected[path]=self.profile if value=='same' else b'different'
                    path.write_bytes(expected[path])
            metadata={'profile_uuid':self.uuid,'identity_sha1':'ABCDEF','bundle_id':'example.test','team_id':'TEST'}
            def security(args):
                commands.append(args)
                if args[0]=='list-keychains':return '"/tmp/original.keychain-db"\n'
                if args[0]=='create-keychain':Path(args[-1]).touch()
                if args[0]=='delete-keychain':Path(args[-1]).unlink()
                if args[0]=='import' and fail_import:raise signing.SigningError('IMPORT_FAILED')
                if args[0]=='find-identity':
                    if race_at is not None:
                        expected[profiles[race_at]]=b'concurrent-profile'
                        profiles[race_at].write_bytes(expected[profiles[race_at]])
                    return 'ABCDEF'
                return ''
            with patch.object(Path,'home',return_value=home),patch.object(signing,'security',side_effect=security),patch.object(signing,'validate',return_value=(metadata,b'dummy-p12',self.profile)):
                yield SimpleNamespace(home=home,folder=folder,profiles=profiles,expected=expected,commands=commands)

    def prepare(self,fixture):
        return signing.prepare(fixture.folder,{'IOS_CERTIFICATE_PASSWORD':'dummy-password'})

    def assert_preserved(self,fixture):
        self.assertFalse(fixture.folder.exists())
        for profile in fixture.profiles:
            self.assertEqual(profile.exists(),profile in fixture.expected)
            if profile in fixture.expected:self.assertEqual(profile.read_bytes(),fixture.expected[profile])

    def test_all_existing_profile_combinations_are_preserved(self):
        for initial in itertools.product(('absent','same','different'),repeat=2):
            with self.subTest(initial=initial),self.fixture(initial) as fixture:
                if 'different' in initial:
                    with self.assertRaisesRegex(signing.SigningError,'EXISTING_PROFILE_DIFFERS'):self.prepare(fixture)
                    self.assertEqual(fixture.commands,[])
                else:
                    self.prepare(fixture)
                    state=json.loads((fixture.folder/'state.json').read_text())
                    locations={entry['location'] for entry in state['created_profiles']}
                    self.assertEqual(locations,{name for name,value in zip(signing.PROFILE_DIRECTORIES,initial) if value=='absent'})
                    signing.clean(fixture.folder)
                    signing.clean(fixture.folder)
                self.assert_preserved(fixture)

    def test_import_failure_preserves_every_existing_profile_combination(self):
        for initial in itertools.product(('absent','same'),repeat=2):
            with self.subTest(initial=initial),self.fixture(initial,fail_import=True) as fixture:
                with self.assertRaisesRegex(signing.SigningError,'IMPORT_FAILED'):self.prepare(fixture)
                self.assert_preserved(fixture)

    def test_profile_write_failure_cleans_only_previously_created_profiles(self):
        original=signing.private_write
        for index in (0,1):
            for other in ('absent','same'):
                initial=['absent','absent'];initial[1-index]=other
                with self.subTest(index=index,other=other),self.fixture(initial) as fixture:
                    def write(path,content):
                        if path==fixture.profiles[index]:raise OSError('synthetic write failure')
                        return original(path,content)
                    with patch.object(signing,'private_write',side_effect=write):
                        with self.assertRaises(OSError):self.prepare(fixture)
                    self.assert_preserved(fixture)

    def exercise_actual_profile_failure(self,kind):
        original_write=signing.private_write
        original_fdopen=signing.os.fdopen
        for index in (0,1):
            initial=['same','same'];initial[index]='absent'
            with self.subTest(index=index,failure=kind),self.fixture(tuple(initial)) as fixture:
                observed=[]
                class FailingStream:
                    def __init__(self,stream):self.stream=stream
                    def __enter__(self):return self
                    def __exit__(self,error_type,error,traceback):
                        if kind=='close' and error_type is None:
                            self.stream.close()
                            observed.append('close')
                            raise OSError('synthetic close failure')
                        return self.stream.__exit__(error_type,error,traceback)
                    def write(self,content):
                        if kind=='write':
                            self.stream.write(content[:3]);self.stream.flush()
                            observed.append(signing.os.fstat(self.stream.fileno()).st_size)
                            raise OSError('synthetic partial write failure')
                        return self.stream.write(content)
                    def flush(self):return self.stream.flush()
                    def fileno(self):return self.stream.fileno()
                def write(path,content):
                    if path!=fixture.profiles[index]:return original_write(path,content)
                    if kind=='fsync':
                        def fail_sync(_):
                            observed.append('fsync')
                            raise OSError('synthetic fsync failure')
                        with patch.object(signing.os,'fsync',side_effect=fail_sync):
                            return original_write(path,content)
                    with patch.object(signing.os,'fdopen',side_effect=lambda *a,**kw:FailingStream(original_fdopen(*a,**kw))):
                        return original_write(path,content)
                with patch.object(signing,'private_write',side_effect=write):
                    with self.assertRaises(OSError):self.prepare(fixture)
                self.assertEqual(observed,[3] if kind=='write' else [kind])
                self.assert_preserved(fixture)
                for profile in fixture.profiles:self.assertEqual(list(profile.parent.glob('.*.partial')),[])
                # A failed write never publishes an incomplete UUID profile, so
                # ordinary preparation can immediately retry without manual repair.
                self.prepare(fixture)
                signing.clean(fixture.folder)
                self.assert_preserved(fixture)

    def test_partial_profile_write_does_not_publish_and_can_retry(self):
        self.exercise_actual_profile_failure('write')

    def test_profile_close_failure_does_not_publish_and_can_retry(self):
        self.exercise_actual_profile_failure('close')

    def test_profile_fsync_failure_does_not_publish_and_can_retry(self):
        self.exercise_actual_profile_failure('fsync')

    def test_ledger_save_failure_cleans_its_own_new_profile(self):
        original=Path.write_text;failed=False
        with self.fixture() as fixture:
            def write(path,content,*args,**kwargs):
                nonlocal failed
                if path==fixture.folder/'state.json' and json.loads(content)['created_profiles'] and not failed:
                    failed=True;raise OSError('synthetic state save failure')
                return original(path,content,*args,**kwargs)
            with patch.object(Path,'write_text',new=write):
                with self.assertRaises(OSError):self.prepare(fixture)
            self.assertTrue(failed)
            self.assert_preserved(fixture)

    def test_profile_appearing_after_preflight_is_preserved(self):
        for index in (0,1):
            with self.subTest(index=index),self.fixture(race_at=index) as fixture:
                with self.assertRaisesRegex(signing.SigningError,'EXISTING_PROFILE_DIFFERS'):self.prepare(fixture)
                self.assert_preserved(fixture)

    def test_profile_appearing_between_check_and_create_is_preserved(self):
        original=signing.private_write
        for index in (0,1):
            with self.subTest(index=index),self.fixture() as fixture:
                def write(path,content):
                    if path==fixture.profiles[index]:
                        fixture.expected[path]=b'concurrent-profile'
                        path.write_bytes(fixture.expected[path])
                    return original(path,content)
                with patch.object(signing,'private_write',side_effect=write):
                    with self.assertRaises(FileExistsError):self.prepare(fixture)
                self.assert_preserved(fixture)

    def test_profile_appearing_at_atomic_publication_is_preserved(self):
        original_link=signing.os.link
        for index in (0,1):
            initial=['same','same'];initial[index]='absent'
            with self.subTest(index=index),self.fixture(tuple(initial)) as fixture:
                def link(source,destination,*args,**kwargs):
                    if destination==fixture.profiles[index]:
                        fixture.expected[destination]=b'concurrent-profile'
                        destination.write_bytes(fixture.expected[destination])
                    return original_link(source,destination,*args,**kwargs)
                with patch.object(signing.os,'link',side_effect=link):
                    with self.assertRaises(FileExistsError):self.prepare(fixture)
                self.assert_preserved(fixture)
                for profile in fixture.profiles:self.assertEqual(list(profile.parent.glob('.*.partial')),[])

    def test_staging_cleanup_failure_rolls_back_only_own_published_profile(self):
        original_unlink=Path.unlink
        for index in (0,1):
            for replacement in ('none','file','symlink','modified'):
                initial=['same','same'];initial[index]='absent'
                with self.subTest(index=index,replacement=replacement),self.fixture(tuple(initial)) as fixture:
                    destination=fixture.profiles[index];failed=False
                    def unlink(path,*args,**kwargs):
                        nonlocal failed
                        if not failed and path.parent==destination.parent and path.name.startswith('.'+destination.name+'.') and path.name.endswith('.partial'):
                            self.assertEqual(destination.read_bytes(),self.profile)
                            failed=True
                            if replacement!='none':
                                fixture.expected[destination]=b'concurrent-profile'
                                if replacement=='file':
                                    concurrent=fixture.home/'concurrent';concurrent.write_bytes(fixture.expected[destination]);concurrent.replace(destination)
                                elif replacement=='symlink':
                                    concurrent=fixture.home/'concurrent';concurrent.write_bytes(fixture.expected[destination]);original_unlink(destination);destination.symlink_to(concurrent)
                                else:destination.write_bytes(fixture.expected[destination])
                            raise OSError('synthetic staging cleanup failure')
                        return original_unlink(path,*args,**kwargs)
                    with patch.object(Path,'unlink',new=unlink):
                        with self.assertRaisesRegex(OSError,'synthetic staging cleanup failure'):self.prepare(fixture)
                    self.assertTrue(failed)
                    self.assert_preserved(fixture)
                    if replacement=='symlink':self.assertTrue(destination.is_symlink())
                    for profile in fixture.profiles:self.assertEqual(list(profile.parent.glob('.*.partial')),[])
                    if replacement=='none':
                        self.prepare(fixture)
                        signing.clean(fixture.folder)
                        self.assert_preserved(fixture)

    def test_changed_profile_is_preserved(self):
        with self.fixture(('absent','same')) as fixture:
            self.prepare(fixture)
            fixture.profiles[0].write_bytes(b'changed')
            with self.assertRaisesRegex(signing.SigningError,'PROFILE_CHANGED'):signing.clean(fixture.folder)
            self.assertEqual(fixture.profiles[0].read_bytes(),b'changed')
            self.assertEqual(fixture.profiles[1].read_bytes(),self.profile)
            self.assertTrue((fixture.folder/'state.json').exists())

    def test_identical_replacement_inode_is_preserved(self):
        with self.fixture(('absent','same')) as fixture:
            self.prepare(fixture)
            fixture.profiles[0].rename(fixture.home/'original-profile')
            fixture.profiles[0].write_bytes(self.profile)
            with self.assertRaisesRegex(signing.SigningError,'PROFILE_CHANGED'):signing.clean(fixture.folder)
            self.assertEqual(fixture.profiles[0].read_bytes(),self.profile)
            self.assertEqual(fixture.profiles[1].read_bytes(),self.profile)

    def test_state_cannot_select_arbitrary_paths_or_uuids(self):
        for invalid in ('location','uuid','device','duplicate'):
            with self.subTest(invalid=invalid),self.fixture(('absent','same')) as fixture:
                self.prepare(fixture)
                statefile=fixture.folder/'state.json';state=json.loads(statefile.read_text())
                if invalid=='location':state['created_profiles'][0]['location']=str(fixture.home/'outside')
                elif invalid=='uuid':state['profile_uuid']='../../outside'
                elif invalid=='device':state['created_profiles'][0]['device']=True
                else:state['created_profiles'].append(state['created_profiles'][0])
                statefile.write_text(json.dumps(state));before=len(fixture.commands)
                with self.assertRaises(signing.SigningError):signing.clean(fixture.folder)
                self.assertEqual(len(fixture.commands),before)
                for profile in fixture.profiles:self.assertEqual(profile.read_bytes(),self.profile)

    def test_legacy_shared_boolean_preserves_all_profiles(self):
        with self.fixture(('same','absent')) as fixture:
            self.prepare(fixture)
            statefile=fixture.folder/'state.json';state=json.loads(statefile.read_text())
            state.pop('state_version');state.pop('created_profiles');state['profile_created']=True
            statefile.write_text(json.dumps(state));signing.clean(fixture.folder)
            self.assertFalse(fixture.folder.exists())
            for profile in fixture.profiles:self.assertEqual(profile.read_bytes(),self.profile)

    def test_preflight_rejects_symlinked_profile_directory(self):
        with self.fixture() as fixture:
            outside=fixture.home/'outside';outside.mkdir()
            directory=fixture.profiles[1].parent;directory.rmdir();directory.symlink_to(outside,target_is_directory=True)
            with self.assertRaisesRegex(signing.SigningError,'UNSAFE_PROFILE_DIRECTORY'):self.prepare(fixture)
            self.assertEqual(fixture.commands,[])
            self.assertFalse(fixture.folder.exists())
            self.assertEqual(list(outside.iterdir()),[])

    def test_preflight_preserves_existing_symlink_profile(self):
        with self.fixture() as fixture:
            outside=fixture.home/'outside';outside.write_bytes(b'preserve')
            fixture.profiles[0].symlink_to(outside)
            with self.assertRaisesRegex(signing.SigningError,'EXISTING_PROFILE_DIFFERS'):self.prepare(fixture)
            self.assertEqual(fixture.commands,[])
            self.assertFalse(fixture.folder.exists())
            self.assertEqual(outside.read_bytes(),b'preserve')
            self.assertTrue(fixture.profiles[0].is_symlink())

    def test_cleanup_refuses_symlinked_state_and_keychain(self):
        for name in ('state.json','build.keychain-db'):
            with self.subTest(name=name),self.fixture(('absent','same')) as fixture:
                self.prepare(fixture);outside=fixture.home/'outside';outside.write_bytes(b'preserve')
                (fixture.folder/name).unlink();(fixture.folder/name).symlink_to(outside)
                before=len(fixture.commands)
                with self.assertRaises(signing.SigningError):signing.clean(fixture.folder)
                self.assertEqual(outside.read_bytes(),b'preserve')
                self.assertEqual(len(fixture.commands),before)
                for profile in fixture.profiles:self.assertEqual(profile.read_bytes(),self.profile)

if __name__=='__main__':unittest.main()
