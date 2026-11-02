"""Validate injected iOS signing material without printing secret values."""
import base64,hashlib,json,os,plistlib,subprocess,tempfile
from pathlib import Path
from datetime import datetime,timezone

def checked(args,*,input=None):
 p=subprocess.run(args,input=input,capture_output=True,timeout=30)
 if p.returncode:raise ValueError('Signing material verification failed')
 return p.stdout

def validate(environment):
 p12=base64.b64decode(environment['IOS_CERTIFICATE_BASE64'],validate=True)
 profile=base64.b64decode(environment['IOS_PROVISIONING_PROFILE_BASE64'],validate=True)
 password=environment['IOS_CERTIFICATE_PASSWORD']
 if not password or any(c in password for c in '\r\n\x00'):raise ValueError('Invalid P12 password format')
 info=plistlib.loads(checked(['/usr/bin/security','cms','-D'],input=profile))
 if info['Entitlements']['application-identifier'].partition('.')[2]!=environment['IOS_BUNDLE_ID']:raise ValueError('Bundle mismatch')
 if info['TeamIdentifier']!=[environment['APPLE_TEAM_ID']]:raise ValueError('Team mismatch')
 if info['UUID']!=environment['IOS_PROVISIONING_PROFILE_UUID']:raise ValueError('Profile mismatch')
 if info['ExpirationDate']<=datetime.now(timezone.utc).replace(tzinfo=None):raise ValueError('Expired profile')
 if info['Entitlements'].get('get-task-allow'):raise ValueError('Development profile')
 with tempfile.TemporaryDirectory(prefix='codex-ios-check-') as root:
  path=Path(root)/'certificate.p12'
  fd=os.open(path,os.O_CREAT|os.O_EXCL|os.O_WRONLY,0o600)
  with os.fdopen(fd,'wb') as stream:stream.write(p12)
  certificate=checked(['/usr/bin/openssl','pkcs12','-in',str(path),'-passin','stdin','-nokeys'],input=(password+'\n').encode())
  der=checked(['/usr/bin/openssl','x509','-outform','DER'],input=certificate)
  checked(['/usr/bin/openssl','x509','-checkend','0','-noout'],input=certificate)
  if der not in info['DeveloperCertificates']:raise ValueError('Certificate mismatch')
 return {'identity_sha1':hashlib.sha1(der).hexdigest().upper(),'profile_uuid':info['UUID'],'bundle_id':environment['IOS_BUNDLE_ID'],'team_id':environment['APPLE_TEAM_ID'],'profile_expires':info['ExpirationDate'].isoformat()},p12,profile

if __name__=='__main__':
 try:
  result,_,_=validate(os.environ)
  print(json.dumps({'ios_signing_material_valid':True,'profile_expires':result['profile_expires']}))
 except Exception:raise SystemExit('IOS_SIGNING_VALIDATION_FAILED: Check configured material, bundle, team and expiry.') from None
