#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
若依代码生成器 - 命令行入口
RuoYi Python Code Generator CLI

Usage:
    python main.py -t customer_info -m customer
    python main.py -t "customer_info,product_info" -m customer -o ./output
"""

import os
import sys
import argparse
from colorama import init, Fore, Style

# 添加当前目录到路径
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from generator.ruoyi_generator import RuoYiGenerator

# 初始化colorama
init(autoreset=True)


def print_banner():
    """打印欢迎横幅"""
    banner = f"""
{Fore.CYAN}╔══════════════════════════════════════════════════════════╗
║                                                          ║
║     {Fore.YELLOW}若依代码生成器 - Python 版{Fore.CYAN}                          ║
║     RuoYi Code Generator - Python Edition                ║
║                                                          ║
║     完美兼容若依原生生成器输出                              ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝{Style.RESET_ALL}
"""
    print(banner)


def main():
    parser = argparse.ArgumentParser(
        description='若依代码生成器 - 生成可直接导入若依项目的代码',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  %(prog)s -t customer_info                    # 生成单表，自动推断模块名
  %(prog)s -t customer_info -m customer        # 指定模块名
  %(prog)s -t "user,role,menu" -m system       # 批量生成多个表
  %(prog)s -t customer_info -c ./myconfig.yaml # 使用自定义配置
        """
    )
    
    parser.add_argument(
        '-t', '--tables',
        required=True,
        help='数据库表名，多个表用逗号分隔，如: "user_info,product_info"'
    )
    
    parser.add_argument(
        '-m', '--module',
        help='模块名（如: customer, product），不指定则自动推断'
    )
    
    parser.add_argument(
        '-b', '--business',
        help='业务名（如: info, manage），不指定则自动推断'
    )
    
    parser.add_argument(
        '-c', '--config',
        default='config.yaml',
        help='配置文件路径 (默认: config.yaml)'
    )
    
    parser.add_argument(
        '-o', '--output',
        help='输出目录 (默认使用配置文件中的路径)'
    )
    
    parser.add_argument(
        '--tpl',
        choices=['crud', 'tree', 'sub'],
        default='crud',
        help='模板类型: crud=单表, tree=树表, sub=主子表 (默认: crud)'
    )
    
    parser.add_argument(
        '--no-sql',
        action='store_true',
        help='不生成菜单SQL'
    )
    
    args = parser.parse_args()
    
    # 打印横幅
    print_banner()
    
    # 检查配置文件
    if not os.path.exists(args.config):
        print(f"{Fore.RED}❌ 配置文件不存在: {args.config}")
        print(f"{Fore.YELLOW}提示: 请复制 config.yaml.example 为 config.yaml 并配置数据库信息")
        return 1
    
    try:
        # 初始化生成器
        print(f"{Fore.BLUE}📖 加载配置: {args.config}")
        generator = RuoYiGenerator(args.config)
        
        # 如果指定了输出目录，覆盖配置
        if args.output:
            generator.config['generator']['output_path'] = args.output
            generator.writer = __import__('generator.template_engine', fromlist=['CodeFileWriter']).CodeFileWriter(args.output)
        
        # 如果不生成SQL
        if args.no_sql:
            generator.config['generator']['gen_menu_sql'] = False
        
        # 解析表名列表
        tables = [t.strip() for t in args.tables.split(',')]
        
        print(f"{Fore.GREEN}📋 准备生成 {len(tables)} 个表:\n   {', '.join(tables)}\n")
        
        # 批量生成
        results = []
        for table_name in tables:
            try:
                context = generator.generate(
                    table_name=table_name,
                    module_name=args.module,
                    business_name=args.business,
                    tpl_category=args.tpl
                )
                results.append((table_name, True, context.get('ClassName', '')))
            except Exception as e:
                print(f"{Fore.RED}❌ 生成失败 [{table_name}]: {str(e)}")
                results.append((table_name, False, str(e)))
        
        # 打印结果汇总
        print(f"\n{Fore.CYAN}╔══════════════════════════════════════════════════════════╗")
        print(f"║{Fore.YELLOW}                     生成结果汇总                          {Fore.CYAN}║")
        print(f"╠══════════════════════════════════════════════════════════╣")
        
        for table_name, success, info in results:
            if success:
                print(f"║  ✅ {Fore.GREEN}{table_name:<20} -> {info}")
            else:
                print(f"║  ❌ {Fore.RED}{table_name:<20} -> {info}")
        
        print(f"{Fore.CYAN}╚══════════════════════════════════════════════════════════╝\n")
        
        # 输出部署提示
        output_path = generator.config['generator']['output_path']
        print(f"{Fore.GREEN}📁 代码已生成到: {os.path.abspath(output_path)}\n")
        
        print(f"{Fore.YELLOW}部署步骤:")
        print(f"  1. 复制后端代码到 ruoyi-backend:")
        print(f"     cp -r {output_path}/main/java/* ~/ruoyi/ruoyi-backend/ruoyi-system/src/main/java/")
        print(f"     cp -r {output_path}/main/resources/* ~/ruoyi/ruoyi-backend/ruoyi-system/src/main/resources/")
        print(f"")
        print(f"  2. 复制前端代码到 ruoyi-frontend:")
        print(f"     cp -r {output_path}/vue/* ~/ruoyi/ruoyi-frontend/src/")
        print(f"")
        print(f"  3. 执行菜单SQL:")
        print(f"     mysql -u ruoyi -p ry_vue < {output_path}/sql/*_menu.sql")
        print(f"")
        print(f"  4. 重新编译启动:")
        print(f"     cd ~/ruoyi/ruoyi-backend && mvn clean package -DskipTests")
        print(f"     cd ~/ruoyi && ./start.sh")
        print()
        
        return 0
        
    except Exception as e:
        print(f"{Fore.RED}❌ 错误: {str(e)}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == '__main__':
    sys.exit(main())
