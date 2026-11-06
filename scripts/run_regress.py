#!/usr/bin/env python3
# run_regress.py：小回归脚本——用多个种子批量跑同一个仿真，汇总 PASS/FAIL
# 用法（在 WSL 中执行）：python3 run_regress.py [选项]，用 -h 查看所有选项
#
# 背景：
#   - 一次仿真 = 在练习目录里执行 cmd.exe /c run.bat <顶层模块名> <种子>
#     （run.bat 是 Windows 批处理，Vivado 装在 Windows 上，所以从 WSL 里要通过 cmd.exe 调用）
#   - 仿真输出里，tb 会打印 PASS seed:... 或 ERROR errCnt:... 这样的汇总行；
#     编译失败时 run.bat 会打印“编译失败”（cmd.exe 的输出是 GBK 编码）
#   - 每次运行，tb 都会往 <练习目录>/work/sim_result.txt 追加一行汇总

import argparse
import os
import re
import subprocess
import sys
import time


def main():
    # TODO：用 argparse 定义命令行选项，每个都有默认值和 help 说明：
    #       练习目录（默认 ../stage1/01_spram）、顶层模块名（默认 tb_spram）、
    #       运行次数（默认 5）、起始种子（默认 1；种子依次为 起始、起始+1、……）
    #创建解析器
    parse = argparse.ArgumentParser(description='批量跑仿真')
    #定义参数（都有默认值，所以都用可选参数）
    #前两个参数不用传入直接用默认值即可
    parse.add_argument('--dir',default='../stage1/01_spram',help='仿真测试目录，默认../stage1/01_spram')
    parse.add_argument('--tb',default='tb_spram',help='顶层模块名，默认tb_spram')
    parse.add_argument('-r','--runs',type=int,default=5,help='运行次数，默认5')
    parse.add_argument('--startSeed',type=int,default=1,help='起始种子默认为1')
    #得到传入的参数
    args = parse.parse_args()
    '''
        args.dir:仿真测试文件所在目录
        args.tb:顶层模块名
        args.runs:运行次数
        args.startSeed:起始种子
    '''

    # TODO：对每个种子跑一次仿真：
    #       1. 打印正在跑第几次、种子是多少
    #       2. 把这次仿真的完整输出保存到 regress_logs/seed_<种子>.log
    #       3. 根据输出判断这次是 PASS、FAIL 还是编译失败，并记录用时
    os.makedirs('regress_logs',exist_ok=True)#日志目录不存在就创建，已存在不报错
    results = []#每次运行的结果：(种子, 结果, 用时)
    for i in range(args.runs):
        seed = args.startSeed+i#起始种子加运行次数（当前运行的随机种子）
        print(f'第 {i+1}/{args.runs} 次，种子 {seed}')
        #运行仿真，并记录用时
        t0 = time.time()
        r = subprocess.run(['cmd.exe','/c','run.bat',args.tb,str(seed)],
            capture_output=True,text=True,cwd=args.dir,errors='replace'
        )
        used = time.time()-t0
        #将仿真结果写入日志文件（同一个种子重跑时覆盖，所以用 w）
        with open(f'regress_logs/seed_{seed}.log','w',encoding='utf-8') as f:
            f.write(r.stdout)
            f.write(r.stderr)
        #根据正则判断这次的输出是PASS、FAIL还是编译失败
        #run.bat 编译失败时退出码不一定非 0，所以只看输出里有没有 tb 打印的汇总行
        m = re.search(r'^(PASS|ERROR)\s',r.stdout,re.MULTILINE)#re.MULTILINE：让 ^ 匹配每一行的行首(多行匹配，只返回第一次匹配到的位置)
        if not m:
            result = '编译失败'#没有汇总行：仿真没跑起来
        elif m.group(1)=='PASS':
            result = 'PASS'
        else:
            result = 'FAIL'
        print(f'{result}，用时 {used:.1f} 秒')
        results.append((seed,result,used))

    # TODO：全部跑完后打印表格（种子、结果、用时）和汇总（总次数、PASS 次数、FAIL 次数）
    resultLog = ['种子','结果','用时']
    print('\t'.join(resultLog))
    for seed, result, used in results:
        print(f'{seed}\t{result}\t{used:.1f}')
        #不能用这个print('\t'.join(temptempResult))，因为join只能连接字符串，如果想使用需要加入列表的时候转换为字符串
    passCnt = sum(1 for _,result,_ in results if result=='PASS')#统计pass的次数，也可以前面运行的时候计算
    print(f'总次数：{len(results)}  PASS 次数：{passCnt}  FAIL 次数：{len(results)-passCnt}（含编译失败）')

    # TODO：调用 parse_result.py 解析 <练习目录>/work/sim_result.txt，把它的输出打印出来
    print('\n---- parse_result.py ----')
    sys.stdout.flush()#先把上面的打印输出完，避免和子程序的输出顺序错乱
    subprocess.run(['python3','parse_result.py',os.path.join(args.dir,'work','sim_result.txt')])#不抓输出，直接打印到屏幕

    # TODO：全部 PASS 时退出码为 0，否则为 1
    sys.exit(0 if passCnt==len(results) else 1)


if __name__ == "__main__":
    main()
