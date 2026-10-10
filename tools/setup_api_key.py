"""Store the complete project API key in macOS Keychain without shell arguments.

Run interactively: python3 tools/setup_api_key.py
Uses native Security APIs rather than the security CLI password-entry buffer.
"""
import ctypes
import getpass
import os
import sys

from generate_ai_art import KEYCHAIN_SERVICE


def main():
    if sys.platform != 'darwin':
        sys.exit('This helper is for macOS. On other systems, set OPENAI_API_KEY.')
    if not sys.stdin.isatty():
        sys.exit('Run this helper in your terminal so the key can be entered privately.')
    key = getpass.getpass('Paste the complete OpenAI API key (hidden): ').strip()
    if not key.startswith('sk-') or any(char.isspace() for char in key) or '*' in key:
        sys.exit('Expected a complete API key beginning with sk-, without quotes or masking.')
    if any(char in key for char in ['"', "'", '…']) or '...' in key:
        sys.exit('Paste the original key without quotes or ellipses.')
    try:
        secret = key.encode('ascii')
    except UnicodeEncodeError:
        sys.exit('The API key must contain ASCII characters only.')
    service = KEYCHAIN_SERVICE.encode()
    account = os.environ.get('USER', getpass.getuser()).encode()
    security = ctypes.CDLL('/System/Library/Frameworks/Security.framework/Security')
    core = ctypes.CDLL('/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation')
    pointer = ctypes.c_void_p
    uint = ctypes.c_uint32
    char_pointer = ctypes.c_char_p
    security.SecKeychainFindGenericPassword.argtypes = [
        pointer, uint, char_pointer, uint, char_pointer,
        ctypes.POINTER(uint), ctypes.POINTER(pointer), ctypes.POINTER(pointer),
    ]
    security.SecKeychainFindGenericPassword.restype = ctypes.c_int32
    security.SecKeychainAddGenericPassword.argtypes = [
        pointer, uint, char_pointer, uint, char_pointer, uint, char_pointer, ctypes.POINTER(pointer),
    ]
    security.SecKeychainAddGenericPassword.restype = ctypes.c_int32
    security.SecKeychainItemModifyAttributesAndData.argtypes = [pointer, pointer, uint, char_pointer]
    security.SecKeychainItemModifyAttributesAndData.restype = ctypes.c_int32
    security.SecKeychainItemFreeContent.argtypes = [pointer, pointer]
    security.SecKeychainItemFreeContent.restype = ctypes.c_int32
    core.CFRelease.argtypes = [pointer]
    core.CFRelease.restype = None

    item = pointer()
    status = security.SecKeychainFindGenericPassword(
        None, len(service), service, len(account), account, None, None, ctypes.byref(item),
    )
    try:
        if status == 0:
            status = security.SecKeychainItemModifyAttributesAndData(item, None, len(secret), secret)
        elif status == -25300:  # errSecItemNotFound
            status = security.SecKeychainAddGenericPassword(
                None, len(service), service, len(account), account,
                len(secret), secret, ctypes.byref(item),
            )
        if status != 0:
            sys.exit(f'Keychain could not save the key (macOS error {status}).')
    finally:
        if item.value:
            core.CFRelease(item)

    length = uint()
    stored = pointer()
    status = security.SecKeychainFindGenericPassword(
        None, len(service), service, len(account), account,
        ctypes.byref(length), ctypes.byref(stored), None,
    )
    try:
        if status != 0 or ctypes.string_at(stored, length.value) != secret:
            sys.exit('The saved key could not be verified. No secret has been displayed.')
    finally:
        if stored.value:
            security.SecKeychainItemFreeContent(None, stored)
    print(f'Saved {len(secret)} characters to {KEYCHAIN_SERVICE}; exact read-back verified.')
    print('Storage is verified; API validity will be checked on the next request.')
    if os.environ.get('OPENAI_API_KEY'):
        print('Note: OPENAI_API_KEY is set and takes precedence over the Keychain entry.')


if __name__ == '__main__':
    main()
