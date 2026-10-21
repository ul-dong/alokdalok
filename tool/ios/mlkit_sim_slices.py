#!/usr/bin/env python3
"""ML Kit 정적 프레임워크에 'arm64 시뮬레이터' 조각을 만들어 준다.

Google ML Kit(iOS)는 시뮬레이터용으로 x86_64 조각만 내놓는다. Xcode 27 의 iOS 27 시뮬레이터는
x86_64(Rosetta) 앱을 돌리지 못하므로, 실기기용 arm64 조각의 각 오브젝트 파일에서
LC_BUILD_VERSION 의 platform 값을 iOS(2) → iOS 시뮬레이터(7)로 바꾼 사본을 만든다
(널리 쓰이는 'arm64-to-sim' 방식, 코드는 그대로).

사용: mlkit_sim_slices.py <Pods 폴더> <출력 폴더> <프레임워크 이름>...
결과: <출력 폴더>/<이름>.framework (x86_64 시뮬레이터 + arm64 시뮬레이터)
ios/Podfile 의 post_install 이 부르고, 시뮬레이터 빌드에서만 이 폴더를 먼저 찾게 한다.
실기기(App Store) 빌드는 원래 프레임워크를 그대로 쓴다.
"""
import os
import shutil
import struct
import subprocess
import sys
import tempfile

LC_BUILD_VERSION = 0x32
LC_VERSION_MIN_IPHONEOS = 0x25
MH_MAGIC_64 = 0xFEEDFACF
PLATFORM_IOS, PLATFORM_IOSSIM = 2, 7


def patch_macho(buf, off, name):
    magic, _, _, _, ncmds, _, _, _ = struct.unpack_from("<IiiIIIII", buf, off)
    if magic != MH_MAGIC_64:
        return 0
    p = off + 32
    n = 0
    for _ in range(ncmds):
        cmd, size = struct.unpack_from("<II", buf, p)
        if cmd == LC_BUILD_VERSION:
            plat = struct.unpack_from("<I", buf, p + 8)[0]
            if plat == PLATFORM_IOS:
                struct.pack_into("<I", buf, p + 8, PLATFORM_IOSSIM)
                n += 1
        elif cmd == LC_VERSION_MIN_IPHONEOS:
            raise SystemExit(f"{name}: LC_VERSION_MIN_IPHONEOS 는 바꿀 수 없어요")
        p += size
    return n


def patch_archive(path):
    buf = bytearray(open(path, "rb").read())
    if buf[:4] == struct.pack("<I", MH_MAGIC_64):  # 오브젝트 하나로 된 조각
        n = patch_macho(buf, 0, path)
        open(path, "wb").write(buf)
        return n
    if buf[:8] != b"!<arch>\n":
        raise SystemExit(f"{path}: ar 묶음도 Mach-O 도 아니에요")
    p, count = 8, 0
    while p + 60 <= len(buf):
        hdr = buf[p:p + 60]
        name = hdr[:16].decode().strip()
        size = int(hdr[48:58].decode().strip())
        data = p + 60
        if name.startswith("#1/"):  # BSD 긴 이름: 이름이 데이터 앞에 붙는다
            nlen = int(name[3:])
            name = buf[data:data + nlen].rstrip(b"\0").decode()
            data += nlen
        if not name.startswith("__.SYMDEF"):
            count += patch_macho(buf, data, name)
        p += 60 + size
        p += p & 1
    open(path, "wb").write(buf)
    return count


def main():
    pods, out, names = sys.argv[1], sys.argv[2], sys.argv[3:]
    os.makedirs(out, exist_ok=True)
    for name in names:
        src = os.path.join(pods, name, "Frameworks", f"{name}.framework")
        if not os.path.isdir(src):
            print(f"[mlkit-sim] 건너뜀(없음): {name}")
            continue
        dst = os.path.join(out, f"{name}.framework")
        stamp = os.path.join(dst, ".src_mtime")
        mtime = str(os.path.getmtime(os.path.join(src, name)))
        if os.path.exists(stamp) and open(stamp).read() == mtime:
            continue
        shutil.rmtree(dst, ignore_errors=True)
        shutil.copytree(src, dst, symlinks=True)
        binary = os.path.join(dst, name)
        with tempfile.TemporaryDirectory() as tmp:
            arm = os.path.join(tmp, "arm64.a")
            x86 = os.path.join(tmp, "x86_64.a")
            subprocess.run(["lipo", "-thin", "arm64", binary, "-output", arm], check=True)
            subprocess.run(["lipo", "-thin", "x86_64", binary, "-output", x86], check=True)
            n = patch_archive(arm)
            subprocess.run(["lipo", "-create", x86, arm, "-output", binary], check=True)
        open(stamp, "w").write(mtime)
        print(f"[mlkit-sim] {name}: 오브젝트 {n}개를 arm64 시뮬레이터용으로 표시")


if __name__ == "__main__":
    main()
