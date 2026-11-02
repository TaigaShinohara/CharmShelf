"""Re-enter a trusted command under the configured 1Password runner."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys


PROFILE_MARKER = 'CODEX_AUTH_PROFILE_V2_ID'
SIGNING_FIELDS = {
    'android': ('CODEX_ANDROID_KEY_PROPERTIES',),
    'ios': ('CODEX_IOS_KEYCHAIN_PATH', 'CODEX_IOS_IDENTITY_SHA1',
            'IOS_PROVISIONING_PROFILE_UUID', 'IOS_BUNDLE_ID', 'APPLE_TEAM_ID'),
}


def _identity(context):
    # Hash reference metadata only, never resolved credentials or file contents.
    return hashlib.sha256(json.dumps(context, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def auth_selector(profile):
    auth = profile.get('local_auth')
    if not isinstance(auth, dict):
        raise ValueError('local_auth is required')
    mode = auth.get('mode')
    if mode == 'desktop':
        account = auth.get('account')
        if account == '':
            account = None
        prompt = auth.get('prompt_for_authentication', False)
        if (account is not None and (not isinstance(account, str) or not account.strip())) or not isinstance(prompt, bool):
            raise ValueError('invalid desktop selector')
        return {'mode': mode, 'account': account, 'prompt_for_authentication': prompt}
    if mode == 'service_account_keychain':
        fields = ('keychain_service', 'keychain_account')
        if not all(isinstance(auth.get(key), str) and auth[key].strip() for key in fields):
            raise ValueError('invalid Keychain selector')
        return {'mode': mode, **{key: auth[key] for key in fields}}
    raise ValueError('unsupported local_auth mode')


def profile_identity(profile, profile_path):
    context = {key: profile.get(key) for key in ('service', 'environment', 'secret_references')}
    context.update(version=2, local_auth=auth_selector(profile),
                   profile_path=str(Path(profile_path).resolve()))
    return _identity(context)


def signing_identity(profile_path, platform, environment):
    profile = json.loads(Path(profile_path).read_text())
    fields = SIGNING_FIELDS[platform]
    metadata = {name: environment.get(name) for name in fields}
    if not all(isinstance(value, str) and value for value in metadata.values()):
        raise ValueError('signing metadata is incomplete')
    path = Path(metadata[fields[0]])
    if not path.is_absolute() or not path.is_file():
        raise ValueError('signing material is unavailable')
    return _identity({'profile': profile_identity(profile, profile_path),
                      'platform': platform, 'metadata': metadata})


def signing_ready(profile_path, platform, environment=None):
    environment = os.environ if environment is None else environment
    marker = environment.get('CODEX_' + platform.upper() + '_SIGNING_V2_ID')
    if not marker:
        return False
    try:
        return marker == signing_identity(profile_path, platform, environment)
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        return False


def bind_signing_context(profile_path, platform, environment):
    profile = json.loads(Path(profile_path).read_text())
    if environment.get(PROFILE_MARKER) != profile_identity(profile, profile_path):
        raise SystemExit('SIGNING_CONTEXT_CHANGED: Resolve the selected signing profile again.')
    environment['CODEX_' + platform.upper() + '_SIGNING_V2_ID'] = signing_identity(profile_path, platform, environment)


def ensure_signing(profile_path, platform, command):
    if signing_ready(profile_path, platform):
        return
    runner_home = Path(os.environ.get('CODEX_AUTH_HOME', Path.home() / '.local/share/codex-auth'))
    signer = runner_home / (platform + '_signing.py')
    if not signer.is_file():
        raise SystemExit('NOT_CONFIGURED: Install the shared v2 signing runner; see auth/README.md.')
    # Older runners reject this option before authentication, instead of looping.
    raise SystemExit(subprocess.call([sys.executable, str(signer), '--context-version', '2',
        '--profile', str(profile_path), '--', *command]))


def ensure(profile_path, command):
    try:
        profile = json.loads(Path(profile_path).read_text())
        names = list(profile['secret_references'])
        if not names:
            raise ValueError()
        identity = profile_identity(profile, profile_path)
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        raise SystemExit('NOT_CONFIGURED: 1Passwordプロファイルを設定してください。') from None
    injected=all(os.environ.get(name) and not os.environ[name].startswith('op://') for name in names)
    marker=os.environ.get(PROFILE_MARKER)==identity
    cloud_context=profile.get('cloud',{}).get('context')
    cloud=bool(cloud_context) and os.environ.get('CODEX_AUTH_CONTEXT')==cloud_context
    # Context markers prevent accidental use of another shell/project's keys.
    # They are not a security boundary against code with this user's privileges.
    if injected and (marker or cloud):
        return
    if cloud:
        raise SystemExit('NOT_CONFIGURED: このクラウド環境のNetwork secretsを設定してください。')
    runner_home = Path(os.environ.get('CODEX_AUTH_HOME', Path.home() / '.local/share/codex-auth'))
    runner = runner_home / 'run.py'
    if not runner.is_file():
        raise SystemExit('NOT_CONFIGURED: 共通1Passwordランナーを導入し、CODEX_AUTH_HOMEを指定してください。')
    # No secret appears in argv. op run handles masking and signal forwarding.
    raise SystemExit(subprocess.call([sys.executable, str(runner), '--context-version', '2', '--profile', str(profile_path), '--', *command]))


if __name__ == '__main__':
    if len(sys.argv) == 4 and sys.argv[1] == '--check-signing':
        raise SystemExit(0 if signing_ready(sys.argv[2], sys.argv[3]) else 1)
    if len(sys.argv) < 4 or sys.argv[2] != '--':
        raise SystemExit('Usage: project_auth.py PROFILE -- COMMAND [ARGS...]')
    ensure(sys.argv[1], sys.argv[3:])
    os.execvp(sys.argv[3], sys.argv[3:])
