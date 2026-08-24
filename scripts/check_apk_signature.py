"""Check if APK has V1/V2/V3 signature by inspecting ZIP structure."""
import sys, struct, os

def find_apk_signing_block(data):
    """APK Signing Block is between central directory and end of central directory."""
    # Find End of Central Directory (EOCD)
    eocd_magic = b'PK\x05\x06'
    eocd_pos = data.rfind(eocd_magic)
    if eocd_pos < 0:
        return None, "No EOCD found"
    
    # EOCD is at least 22 bytes
    # Comment length is at offset 20-21 (2 bytes, little-endian)
    comment_len = struct.unpack('<H', data[eocd_pos+20:eocd_pos+22])[0]
    
    # APK Signing Block starts before EOCD comment
    # It has a magic string "APK Sig Block 42"
    signing_block_magic = b'APK Sig Block 42'
    
    # Search for the magic in the area before EOCD comment
    search_start = max(0, eocd_pos - 100000)
    pos = data.find(signing_block_magic, search_start, eocd_pos)
    
    if pos >= 0:
        return pos, "Found APK Signing Block"
    
    # Also check for V1 (JAR) signature - META-INF/*.RSA or *.SF
    meta_inf_pos = data.find(b'META-INF/')
    if meta_inf_pos >= 0:
        rsa_pos = data.find(b'META-INF/', meta_inf_pos + 1)
        # Check for RSA/SF files
        for name in [b'META-INF/CERT.RSA', b'META-INF/ANDROIDD.RSA', b'META-INF/']:
            if data.find(name) >= 0:
                return -1, "V1 (JAR) signature files found"
    
    return None, "No signing block found"

def main():
    apk_path = sys.argv[1] if len(sys.argv) > 1 else r'D:\claude\work\cn_com_lange\word_app\build\app\outputs\flutter-apk\app-release.apk'
    
    with open(apk_path, 'rb') as f:
        data = f.read()
    
    print(f"APK size: {len(data)} bytes ({len(data)/1024/1024:.1f} MB)")
    
    # Check for V1 signature (META-INF files)
    has_v1 = False
    for name in [b'META-INF/CERT.RSA', b'META-INF/CERT.SF', b'META-INF/MANIFEST.MF']:
        if data.find(name) >= 0:
            has_v1 = True
            print(f"  V1 signature file found: {name.decode()}")
    
    if not has_v1:
        print("  No V1 (JAR) signature files in META-INF")
    
    # Check for V2/V3 signature (APK Signing Block)
    pos, msg = find_apk_signing_block(data)
    print(f"\nAPK Signing Block: {msg}")
    if pos and pos > 0:
        print(f"  Position: {pos} bytes from start")
        # Read the signing block to find signature versions
        # The block starts with size (8 bytes), then pairs of (id, data), then size again, then magic
        try:
            block_size = struct.unpack('<Q', data[pos:pos+8])[0]
            print(f"  Block size: {block_size} bytes")
            # Read signer data
            offset = pos + 8
            signer_versions = []
            while offset < pos + 8 + block_size - 16:
                item_id = struct.unpack('<I', data[offset:offset+4])[0]
                item_data_len = struct.unpack('<I', data[offset+4:offset+8])[0]
                if item_id == 0x7109871a:
                    signer_versions.append("V2")
                elif item_id == 0xf05368c0:
                    signer_versions.append("V3")
                offset += 8 + item_data_len
            if signer_versions:
                print(f"  Signature versions: {', '.join(signer_versions)}")
        except:
            pass
    
    # Summary
    print("\n=== SUMMARY ===")
    if has_v1 or (pos and pos > 0):
        print("APK IS SIGNED")
    else:
        print("APK IS UNSIGNED")

if __name__ == '__main__':
    main()
