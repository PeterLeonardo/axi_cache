#!/usr/bin/env python3
"""
缓存指令生成器
生成格式: <读写控制位> <掩码> <地址> <写数据>
"""

import argparse
import sys
import random
import os

def generate_cache_instructions(num_instructions, output_file, 
                               random_rdwr=False, random_addr=False, 
                               random_data=False, random_mask=False,
                               start_address=0x0, addr_increment=16,
                               default_rdwr=1, default_mask=0xF, 
                               default_data=0x0):
    """
    生成缓存指令文件
    
    Args:
        num_instructions: 指令数量
        output_file: 输出文件名
        random_rdwr: 是否随机生成读写控制位
        random_addr: 是否随机生成地址
        random_data: 是否随机生成数据
        random_mask: 是否随机生成掩码
        start_address: 起始地址
        addr_increment: 地址增量
        default_rdwr: 默认读写控制位 (0=读, 1=写)
        default_mask: 默认掩码 (4位，如0xF=4'b1111)
        default_data: 默认数据
    """
    try:
        with open(output_file, 'w') as f:
            current_address = start_address
            
            for i in range(num_instructions):
                # 生成读写控制位
                if random_rdwr:
                    rdwr = random.randint(0, 1)
                else:
                    rdwr = default_rdwr
                
                # 生成掩码
                if random_mask:
                    mask = random.randint(0, 0xF)  # 4位掩码
                else:
                    mask = default_mask
                
                # 生成地址
                if random_addr:
                    # 随机地址，但保持对齐（低2位为0）
                    addr = random.randint(0, 0xFFFFFFFF) & 0xFFFFFFFC
                else:
                    addr = current_address
                    current_address += addr_increment
                
                # 生成数据
                if random_data:
                    data = random.randint(0, 0xFFFFFFFF)
                else:
                    data = default_data
                
                # 格式化输出
                rdwr_str = f"{rdwr}"
                mask_str = f"{mask:04b}"  # 4位二进制
                addr_str = f"{addr:08X}"  # 8位十六进制
                data_str = f"{data:08X}"  # 8位十六进制
                
                # 写入文件
                line = f"{rdwr_str} {mask_str} {addr_str} {data_str}\n"
                f.write(line)
                
        print(f"成功生成 {num_instructions} 条指令到文件: {output_file}")
        print(f"参数配置:")
        print(f"  - 读写控制位: {'随机' if random_rdwr else f'固定({default_rdwr})'}")
        print(f"  - 掩码: {'随机' if random_mask else f'固定({default_mask:04b})'}")
        print(f"  - 地址: {'随机' if random_addr else f'从0x{start_address:08X}开始，每次增加{addr_increment}'}")
        print(f"  - 数据: {'随机' if random_data else f'固定(0x{default_data:08X})'}")
        
    except Exception as e:
        print(f"错误: 无法写入文件 {output_file}: {e}")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(
        description='缓存指令生成器',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
指令格式:
  <读写控制位> <掩码> <地址> <写数据>
  
示例:
  0 1111 00001000 12345678  # 写入操作，掩码全使能，地址0x1000，数据0x12345678
  1 0000 00001010 00000000  # 读取操作，地址0x1008
  
注意:
  - 读写控制位: 0=读, 1=写
  - 掩码: 4位二进制，表示字节使能 (如1111表示4'b1111)
  - 地址: 32位十六进制
  - 数据: 32位十六进制 (读操作时忽略)
        """
    )
    
    # 必需参数
    parser.add_argument('-n', '--num', type=int, required=True,
                       help='要生成的指令数量')
    parser.add_argument('-o', '--output', type=str, required=True,
                       help='输出文件名')
    
    # 随机性控制参数
    parser.add_argument('--random-rdwr', action='store_true',
                       help='随机生成读写控制位 (否则使用默认值)')
    parser.add_argument('--random-addr', action='store_true',
                       help='随机生成地址 (否则按顺序递增)')
    parser.add_argument('--random-data', action='store_true',
                       help='随机生成数据 (否则使用默认值)')
    parser.add_argument('--random-mask', action='store_true',
                       help='随机生成掩码 (否则使用默认值)')
    
    # 默认值参数
    parser.add_argument('--default-rdwr', type=int, choices=[0, 1], default=1,
                       help='默认读写控制位 (0=读, 1=写，默认: 1)')
    parser.add_argument('--default-mask', type=lambda x: int(x, 2), default=0b1111,
                       help='默认掩码 (二进制，如1111，默认: 1111)')
    parser.add_argument('--default-data', type=lambda x: int(x, 16), default=0x0,
                       help='默认数据 (十六进制，默认: 0x0)')
    
    # 地址参数
    parser.add_argument('-s', '--start-address', type=lambda x: int(x, 16), default=0x0,
                       help='起始地址 (十六进制，默认: 0x0)')
    parser.add_argument('--addr-increment', type=int, default=16,
                       help='地址增量 (默认: 16)')
    
    args = parser.parse_args()
    
    # 参数验证
    if args.num <= 0:
        print("错误: 指令数量必须大于0")
        sys.exit(1)
    
    if args.default_mask < 0 or args.default_mask > 0xF:
        print("错误: 默认掩码必须是4位二进制值 (0-15)")
        sys.exit(1)
    
    if args.addr_increment % 4 != 0:
        print("警告: 地址增量不是4的倍数，可能导致非对齐访问")
    
    # 检查输出文件目录是否存在
    output_dir = os.path.dirname(args.output)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    # 生成指令
    generate_cache_instructions(
        num_instructions=args.num,
        output_file=args.output,
        random_rdwr=args.random_rdwr,
        random_addr=args.random_addr,
        random_data=args.random_data,
        random_mask=args.random_mask,
        start_address=args.start_address,
        addr_increment=args.addr_increment,
        default_rdwr=args.default_rdwr,
        default_mask=args.default_mask,
        default_data=args.default_data
    )

if __name__ == "__main__":
    main()