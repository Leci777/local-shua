"""自动追平 vendor 依赖图：解析失败就补一个包，循环直到成功。

背景：本机 dart 的 pub 无法识别 `sdk: flutter`，所有 Flutter 包都必须有本地 path override。
脚本扫描 pub 报错里的包名，自动下载本地化，循环直到 pub get 通过。
"""
import json
import os
import re
import subprocess
import sys
import tarfile
import urllib.request

APP_DIR = r'E:\workbuddy\2026-10-12-23-50-24\pcvideo-app\app'
VENDOR = os.path.join(APP_DIR, 'vendor')
MIRROR = 'https://mirrors.cloud.tencent.com/dart-pub'
PY = sys.executable

SDK_PATHS = {
    'flutter': 'D:/flutter/packages/flutter',
    'flutter_web_plugins': 'D:/flutter/packages/flutter_web_plugins',
    'flutter_localizations': 'D:/flutter/packages/flutter_localizations',
    'sky_engine': 'D:/flutter/bin/cache/pkg/sky_engine',
    'flutter_gpu': 'D:/flutter/bin/cache/pkg/flutter_gpu',
}


def run_pub_get():
    """跑一次 flutter pub get，返回输出文本"""
    env = dict(os.environ)
    env.update({
        'FLUTTER_ROOT': 'D:/flutter',
        'PUB_CACHE': 'D:/pub-cache',
        'PUB_HOSTED_URL': 'https://mirrors.cloud.tencent.com/dart-pub',
    })
    p = subprocess.run(
        [r'D:\flutter\bin\flutter.bat', 'pub', 'get'],
        cwd=APP_DIR, env=env, capture_output=True, text=True,
        encoding='utf-8', errors='replace', timeout=1800,
    )
    return p.stdout + p.stderr


def latest_version(name):
    try:
        with urllib.request.urlopen(f'{MIRROR}/api/packages/{name}', timeout=20) as r:
            data = json.loads(r.read().decode('utf-8'))
        versions = [v['version'] for v in data.get('versions', []) if not v.get('retracted')]
        return versions[-1] if versions else None
    except Exception:
        return None


def vendorize(name):
    """下载并解压包到 vendor/<name>"""
    target = os.path.join(VENDOR, name)
    if os.path.isdir(target):
        return True
    ver = latest_version(name)
    if not ver:
        return False
    try:
        url = f'{MIRROR}/api/archives/{name}-{ver}.tar.gz'
        with urllib.request.urlopen(url, timeout=60) as r:
            data = r.read()
        os.makedirs(target, exist_ok=True)
        tmp = os.path.join(VENDOR, '_tmp.tar.gz')
        with open(tmp, 'wb') as f:
            f.write(data)
        with tarfile.open(tmp) as t:
            t.extractall(target)
        os.remove(tmp)
        inner = os.path.join(target, name)
        if os.path.isdir(inner):
            for entry in os.listdir(inner):
                src = os.path.join(inner, entry)
                dst = os.path.join(target, entry)
                if os.path.isdir(src):
                    for sub in os.listdir(src):
                        os.replace(os.path.join(src, sub), os.path.join(target, sub))
                else:
                    os.replace(src, dst)
            try:
                os.rmdir(inner)
            except OSError:
                pass
        print(f'  + {name} {ver}', flush=True)
        return True
    except Exception as e:
        print(f'  ! {name} 下载失败: {e}', flush=True)
        if os.path.isdir(target):
            import shutil
            shutil.rmtree(target, ignore_errors=True)
        return False


def vendor_deps_of(name):
    """返回 vendor/<name>/pubspec.yaml 里声明的所有普通依赖名"""
    f = os.path.join(VENDOR, name, 'pubspec.yaml')
    if not os.path.isfile(f):
        return set()
    s = open(f, encoding='utf-8').read()
    deps = set()
    for m in re.finditer(r'^dependencies:\s*$', s, re.M):
        block = s[m.end():]
        # 只取到下一个顶层小节为止
        end = re.search(r'^(dev_dependencies|dependency_overrides|flutter):', block, re.M)
        if end:
            block = block[:end.start()]
        for dm in re.finditer(r'^  ([a-z_0-9]+):\s*(.*)$', block, re.M):
            deps.add(dm.group(1))
        break
    return deps


def collect_needed():
    """从项目依赖出发，广度遍历 vendor 依赖图，返回所有需要本地化的包名"""
    # 先看项目 pubspec 的 dependencies
    pub = open(os.path.join(APP_DIR, 'pubspec.yaml'), encoding='utf-8').read()
    roots = set()
    m = re.search(r'^dependencies:\s*$', pub, re.M)
    if m:
        block = pub[m.end():]
        end = re.search(r'^(dev_dependencies|dependency_overrides|flutter):', block, re.M)
        if end:
            block = block[:end.start()]
        for dm in re.finditer(r'^  ([a-z_0-9]+):', block, re.M):
            roots.add(dm.group(1))

    seen, queue = set(), list(roots)
    while queue:
        name = queue.pop()
        if name in seen or name in SDK_PATHS:
            continue
        seen.add(name)
        for dep in vendor_deps_of(name):
            if dep not in seen:
                queue.append(dep)
    return seen - set(SDK_PATHS)


def write_overrides():
    vendors = sorted(d for d in os.listdir(VENDOR)
                     if os.path.isdir(os.path.join(VENDOR, d)) and not d.startswith('_'))
    lines = ['dependency_overrides:', '  # ===== Flutter SDK 自带包 =====']
    for k, v in SDK_PATHS.items():
        lines += [f'  {k}:', f'    path: {v}']
    lines += ['', '  # ===== 第三方包本地副本（见 vendor/）=====']
    for name in vendors:
        lines += [f'  {name}:', f'    path: vendor/{name}']
    block = '\n'.join(lines) + '\n'
    pub_path = os.path.join(APP_DIR, 'pubspec.yaml')
    s = open(pub_path, encoding='utf-8').read()
    pattern = re.compile(r'dependency_overrides:.*?(?=\nflutter:)', re.S)
    if pattern.search(s):
        s = pattern.sub(block + '\n', s)
    open(pub_path, 'w', encoding='utf-8').write(s)


def main():
    max_rounds = 40
    for i in range(1, max_rounds + 1):
        # 先按依赖图预补齐所有传递依赖，避免逐轮试错
        needed = collect_needed()
        added = [n for n in sorted(needed) if vendorize(n)]
        if added:
            print(f'--- 第 {i} 轮：预补 {len(added)} 个传递依赖 ---', flush=True)
            for a in added:
                print(f'  + {a}', flush=True)

        write_overrides()
        # 清缓存保证重新解析
        for d in ('.dart_tool', 'pubspec.lock'):
            p = os.path.join(APP_DIR, d)
            if os.path.isdir(p):
                import shutil
                shutil.rmtree(p, ignore_errors=True)
            elif os.path.isfile(p):
                os.remove(p)

        out = run_pub_get()
        if os.path.isfile(os.path.join(APP_DIR, '.dart_tool', 'package_config.json')):
            print('\n✓ 依赖解析成功', flush=True)
            return 0

        missing = set(re.findall(r'depends on ([a-z_0-9]+) from (?:sdk|path)', out))
        missing |= set(re.findall(r'local_shua depends on ([a-z_0-9]+)', out))
        missing = {m for m in missing if m not in SDK_PATHS and m != 'flutter'}
        print(f'--- 第 {i} 轮：pub 仍缺 {sorted(missing)} ---', flush=True)
        progress = False
        for name in missing:
            if vendorize(name):
                progress = True
        if not progress:
            print(out[-1500:], flush=True)
            return 1
    return 1


if __name__ == '__main__':
    sys.exit(main())
