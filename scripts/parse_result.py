#!/usr/bin/env python3
# parse_result.py：解析 tb 写的结果日志（如 stage1\01_spram\work\sim_result.txt），汇总多次仿真的结果
# 用法（在 WSL 中执行）：python3 parse_result.py <日志文件路径>
#
# 日志里的汇总行有两种（就是 tb_spram.sv 写进 sim_result.txt 的格式）：
#   PASS seed:1 checkCnt:2019 writeCnt:381 readCnt:502 readPreAddrCnt:27
#   ERROR errCnt:3 seed:7 checkCnt:2019 writeCnt:390 readCnt:488 readPreAddrCnt:9
# 其他行（例如错误明细 time=...）不是汇总行

import os
import re
import sys

def main():
    # TODO：从命令行拿到日志文件路径；没给参数时打印用法并退出
    if len(sys.argv) < 2:#用sys.argv从命令行读取参数，要求输入解析文件的名字和日志文件路径，如果不满足则给出用法并退出报错
        print('用法：python3 parse_result.py <日志文件路径>')
        sys.exit(1)
    log_file = sys.argv[1]#如果满足则取出日志文件路径，sys.argv[0]是解析文件的名字（即parse_result.py）


    # TODO：逐行读文件，用正则解析汇总行，取出：结果（PASS/ERROR）、seed、errCnt（PASS 行当作 0）、
    #       checkCnt、writeCnt、readCnt、readPreAddrCnt；不是汇总行的跳过，并统计跳过了几行
    runs = []#每次运行的结果，一次运行是一个字典
    passCnt = 0#通过次数
    failCnt = 0#错误次数
    jumpCnt = 0#跳过的行数
    with open(log_file,'r',encoding='utf-8') as f:
        for line in f:#遍历每行
            line = line.strip()#去掉行首尾的空白和换行符（包括 Windows 的 \r）
            if not line:#空行直接跳过（不算进跳过的行数）
                continue
            #利用正则解析当前行
            m = re.search(r'^(PASS|ERROR)\s',line)#行首是 PASS 或 ERROR 才是汇总行
            #因为有些行首并非是PASS或ERROR，所以要用^，如果不是则m为空需要跳过
            if not m:#不是汇总行：m 为 None，不能再调用 m.group，要先跳过
                jumpCnt += 1
                continue#终止当前循环
            result = m.group(1)#得到识别的结果：'PASS' 或 'ERROR'
            #因为pass和error的字段顺序不一样，所以转换为字典，不要用列表（字典按名字存取，列表按位置存取）
            fields = dict(re.findall(r'(\w+):(\d+)', line))#后面的“名字:数字”转成字典
            fields.setdefault('errCnt', '0')#PASS 行没有 errCnt，当作 0
            fields['result'] = result#添加pass或error字段
            runs.append(fields)#存储每行的结果，每行是一个字典
            if result == 'PASS':
                passCnt += 1
            else:
                failCnt += 1

    # TODO：打印表格，每次运行一行
    # 不规定字段：日志里出现什么字段就打印什么字段
    # 常用的几列（日志里有的话）放在前面，其余字段按第一次出现的顺序排在后面
    keys = [k for k in ['result', 'seed', 'errCnt', 'checkCnt'] if any(k in r for r in runs)]
    for r in runs:
        for k in r:
            if k not in keys:
                keys.append(k)
    #'分隔符'.join(列表)：把列表里的元素依次连起来，相邻两个元素之间插入前面那个分隔符
    print('\t'.join(keys))                          # 表头，列之间用 Tab 隔开
    for r in runs:
        print('\t'.join(r.get(k, '-') for k in keys))  # 每次运行一行；某次运行缺这个字段时显示 -

    # TODO：打印汇总：运行次数、PASS 次数、FAIL 次数、跳过的行数
    #f'后面接{}，{}里面的内容会转换为字符串
    summary = [f'运行次数：{len(runs)}', f'PASS 次数：{passCnt}', f'FAIL 次数：{failCnt}', f'跳过的行数：{jumpCnt}']

    # TODO：复现检查：同一个 seed 出现多次时，比较各次结果是否完全一样
    by_seed = {}                                    # 按 seed 分组：键是 seed，值是这个 seed 的所有运行
    for r in runs:                                  # 遍历每次运行
        if 'seed' not in r:                         # 日志里没有 seed 字段的运行没法做复现检查，跳过
            continue
        by_seed.setdefault(r['seed'], []).append(r) # 没有这个 seed 就先建空列表，再把这次运行加进去
    for seed, rs in by_seed.items():                # 逐个 seed 检查，rs 是这个 seed 的所有运行
        if len(rs) < 2:                             # 只跑过一次，没法比较
            continue                                # 跳过，看下一个 seed
        if all(r == rs[0] for r in rs):             # 每次运行都和第一次完全相同
            summary.append(f'seed {seed}：运行 {len(rs)} 次，结果一致')
        else:                                       # 至少有一次不同
            summary.append(f'seed {seed}：运行 {len(rs)} 次，结果不一致')
            for r in rs:                            # 列出这个 seed 的每次结果，方便对比
                summary.append('    ' + '\t'.join(r.get(k, '-') for k in keys))  # 缩进 4 格，按表头顺序用 Tab 连成一行

    for s in summary:#summary是一个列表，循环打印会依次打印列表中的元素，也可以直接打印这个列表，打印出来是一行的效果
        print(s)

    # TODO：把汇总写进日志所在目录下的 summary.txt
    out_file = os.path.join(os.path.dirname(log_file), 'summary.txt')
    with open(out_file, 'w', encoding='utf-8') as f:
        for s in summary:
            print(s, file=f)

if __name__ == "__main__":
    main()