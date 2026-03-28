#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
若依代码生成器 - 一体化命令行入口
RuoYi Python Code Generator CLI - All-in-One Edition

Usage:
    # 方式1: 从YAML定义表结构，生成配置文件
    python3 main_allinone.py --schema configs/schemas/test-mvp2.yaml --step=config

    # 方式2: 建表
    python3 main_allinone.py --schema configs/schemas/test-mvp2.yaml --step=create

    # 方式3: 生成代码
    python3 main_allinone.py --schema configs/generated/mvp2_test-config.yaml --step=generate

    # 方式4: 一键完成（读取全局配置）
    python3 main_allinone.py --schema configs/schemas/test-mvp2.yaml --step=all

    # 方式5: 从已有表生成代码（传统模式）
    python3 main_allinone.py -t customer_info -m customer

配置文件: configs/ruoyi-generator.yaml
"""

import os
import sys
import argparse
from colorama import init, Fore, Style

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from generator.ruoyi_generator import RuoYiGenerator
from generator.schema_parser import SchemaParser
from generator.deployer import RuoYiDeployer
from generator.dict_manager import DictManager

init(autoreset=True)


# ============================================
# 全局配置加载
# ============================================

def load_global_config(config_path: str = None) -> dict:
    """加载全局配置文件"""
    import yaml
    
    # 默认路径
    if config_path is None:
        base_dir = os.path.dirname(os.path.abspath(__file__))
        config_path = os.path.join(base_dir, 'configs', 'ruoyi-generator.yaml')
    
    if not os.path.exists(config_path):
        print(f"{Fore.YELLOW}⚠️  全局配置文件不存在: {config_path}")
        print(f"{Fore.YELLOW}使用默认配置")
        return _default_config()
    
    with open(config_path, 'r', encoding='utf-8') as f:
        config = yaml.safe_load(f)
    
    # 转换为绝对路径
    base_dir = os.path.dirname(os.path.abspath(__file__))
    
    # 处理相对路径
    path_keys = ['ruoyi_backend', 'ruoyi_frontend', 'generator_home', 
                 'schema_dir', 'config_dir', 'output_dir', 'scripts_dir']
    for key in path_keys:
        if key in config and config[key] and not os.path.isabs(config[key]):
            config[key] = os.path.normpath(os.path.join(base_dir, config[key]))
    
    return config


def _default_config() -> dict:
    """默认配置"""
    base_dir = os.path.dirname(os.path.abspath(__file__))
    home = os.path.expanduser('~')
    return {
        'ruoyi_backend': f'{home}/.openclaw/workspace/projects/ruoyi/ruoyi-backend',
        'ruoyi_frontend': f'{home}/.openclaw/workspace/projects/ruoyi/ruoyi-frontend',
        'generator_home': base_dir,
        'schema_dir': os.path.join(base_dir, 'configs/schemas'),
        'config_dir': os.path.join(base_dir, 'configs/generated'),
        'dict_dir': os.path.join(base_dir, 'configs/dicts'),  # 字典配置目录
        'output_dir': os.path.join(base_dir, 'output'),
        'scripts_dir': os.path.join(base_dir, 'scripts'),
        'database': {
            'host': 'localhost',
            'port': 3306,
            'name': 'ry_vue',
            'user': 'ruoyi',
            'password': 'ruoyi123',
            'charset': 'utf8mb4'
        },
        'generator': {
            'author': 'ruoyi',
            'package_name': 'com.ruoyi',
            'parent_menu_id': 3,
            'tpl_web_type': 'element-plus'
        }
    }


# 加载全局配置
GLOBAL_CONFIG = load_global_config()


# ============================================
# 工具函数
# ============================================

def print_banner():
    """打印欢迎横幅"""
    banner = f"""
{Fore.CYAN}╔══════════════════════════════════════════════════════════╗
║                                                          ║
║     {Fore.YELLOW}若依代码生成器 - 一体化版{Fore.CYAN}                            ║
║     RuoYi Code Generator - All-in-One                    ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝{Style.RESET_ALL}
"""
    print(banner)


def get_db_config() -> dict:
    """获取数据库配置"""
    db = GLOBAL_CONFIG.get('database', {})
    return {
        'host': db.get('host', 'localhost'),
        'port': db.get('port', 3306),
        'database': db.get('name', 'ry_vue'),
        'user': db.get('user', 'ruoyi'),
        'password': db.get('password', 'ruoyi123'),
        'charset': db.get('charset', 'utf8mb4')
    }


# ============================================
# 核心功能
# ============================================

# 常用系统字典列表（推荐直接使用）
COMMON_SYSTEM_DICTS = {
    'sys_normal_disable': '正常/停用',
    'sys_show_hide': '显示/隐藏',
    'sys_yes_no': '是/否',
    'sys_user_sex': '男/女/未知',
    'sys_notice_type': '通知/公告',
    'sys_notice_status': '通知状态',
    'sys_oper_type': '操作类型',
    'sys_common_status': '通用状态',
}

def check_common_system_dicts(dict_types: list) -> list:
    """检查是否有可使用的系统字典
    
    Returns:
        list of (dict_type, suggestion) tuples
    """
    suggestions = []
    for dt in dict_types:
        # 检查是否是系统字典
        if dt in COMMON_SYSTEM_DICTS:
            suggestions.append((dt, f"✅ 系统字典 '{dt}' ({COMMON_SYSTEM_DICTS[dt]}) - 可直接使用"))
        # 检查是否是新业务字典（有前缀）
        elif dt.startswith('sys_'):
            suggestions.append((dt, f"📝 新业务字典 '{dt}' - 将创建"))
        else:
            suggestions.append((dt, f"⚠️  建议添加前缀: sys_{dt}"))
    return suggestions

def generate_config_from_schema(schema_file: str, output_file: str = None, dict_output_dir: str = None) -> str:
    """从YAML表结构生成完整配置文件"""
    print(f"{Fore.BLUE}📖 解析表结构定义: {schema_file}")
    
    parser = SchemaParser()
    tables = parser.parse_yaml(schema_file)
    
    if not tables:
        print(f"{Fore.RED}❌ 配置文件中没有表定义")
        return None
    
    table = tables[0]
    
    # 处理字典配置
    if table.dicts:
        dict_types = [d.dict_type for d in table.dicts]
        print(f"{Fore.YELLOW}📚 发现 {len(table.dicts)} 个字典配置:")
        print()
        
        # 检查系统字典建议
        suggestions = check_common_system_dicts(dict_types)
        has_system_dict = False
        for dt, msg in suggestions:
            if "✅" in msg:
                print(f"   {Fore.GREEN}{msg}")
                has_system_dict = True
            elif "⚠️" in msg:
                print(f"   {Fore.YELLOW}{msg}")
            else:
                print(f"   {Fore.BLUE}{msg}")
        
        if has_system_dict:
            print()
            print(f"   {Fore.CYAN}💡 提示: 发现可用系统字典！")
            print(f"      如果含义匹配，建议直接使用：")
            print(f"      - 在 column 中设置 dict_type: 系统字典名称")
            print(f"      - 不需要在 dicts 部分定义")
            print(f"      详见: docs/COMPONENT_GUIDE.md")
        print()
        
        # 初始化字典管理器
        db_config = get_db_config()
        dict_manager = DictManager(db_config)
        
        # 确定字典配置输出目录
        if not dict_output_dir:
            dict_output_dir = GLOBAL_CONFIG.get('dict_dir', 'configs/dicts')
        os.makedirs(dict_output_dir, exist_ok=True)
        
        # 检查每个字典的状态
        for dict_item in table.dicts:
            dict_config = dict_manager.generate_dict_config({
                'dict_type': dict_item.dict_type,
                'dict_name': dict_item.dict_name,
                'data': [
                    {
                        'label': d.label,
                        'value': d.value,
                        'sort': d.sort,
                        'is_default': d.is_default,
                        'list_class': d.list_class,
                        'status': d.status
                    }
                    for d in dict_item.data
                ]
            }, table.table_name)
            
            # 对比数据库状态
            comparison = dict_manager.compare_dict_data(
                dict_item.dict_type, 
                dict_config.data
            )
            dict_manager.print_dict_status(dict_item.dict_type, comparison)
            
            # 保存字典配置
            config_file = dict_manager.save_dict_config(dict_config, dict_output_dir)
            print(f"   💾 字典配置: {config_file}")
        
        dict_manager.close()
        print(f"{Fore.GREEN}✅ 字典配置已保存到: {dict_output_dir}")
        print(f"{Fore.YELLOW}💡 如需修改字典数据，请编辑上述文件后重新生成")
        print()
    
    # 生成配置文件
    config_content = parser.generate_config(table)
    
    # 确定输出文件名（使用全局配置中的 config_dir）
    if not output_file:
        config_dir = GLOBAL_CONFIG.get('config_dir', 'configs/generated')
        os.makedirs(config_dir, exist_ok=True)
        output_file = os.path.join(config_dir, f"{table.table_name}-config.yaml")
    
    # 写入文件
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(config_content)
    
    print(f"{Fore.GREEN}✅ 配置文件已生成: {os.path.abspath(output_file)}")
    print(f"{Fore.YELLOW}💡 请编辑配置文件，然后运行:")
    print(f"   python3 main_allinone.py --schema {output_file} --step=generate")
    
    return output_file


def create_tables_from_schema(schema_file: str) -> tuple:
    """从YAML创建数据库表"""
    print(f"{Fore.BLUE}📖 解析表结构定义: {schema_file}")
    
    parser = SchemaParser()
    tables = parser.parse_yaml(schema_file)
    
    print(f"{Fore.GREEN}✅ 发现 {len(tables)} 个表定义")
    
    # 导入PyMySQL
    import pymysql
    
    # 获取数据库配置
    db_config = get_db_config()
    
    # 连接数据库
    conn = pymysql.connect(**db_config)
    
    created_tables = []
    
    try:
        with conn.cursor() as cursor:
            for table in tables:
                print(f"\n{Fore.YELLOW}🗄️  创建表: {table.table_name}")
                ddl = parser.generate_ddl(table)
                
                try:
                    # 删除已存在的表
                    cursor.execute(f"DROP TABLE IF EXISTS `{table.table_name}`")
                    # 创建新表
                    cursor.execute(ddl)
                    conn.commit()
                    print(f"{Fore.GREEN}  ✓ 表创建成功")
                    created_tables.append(table.table_name)
                except Exception as e:
                    print(f"{Fore.RED}  ❌ 表创建失败: {e}")
    finally:
        conn.close()
    
    return created_tables, tables


def generate_code(config_file: str, tables: list = None, schema_file: str = None) -> str:
    """生成代码"""
    if tables is None:
        # 从配置文件生成
        return generate_code_from_config(config_file, schema_file=schema_file)
    
    # 传统模式
    print(f"\n{Fore.CYAN}🔨 开始生成代码...")
    
    gen_config = GLOBAL_CONFIG.get('generator', {})
    
    # 创建临时配置
    import yaml
    temp_config = {
        'database': get_db_config(),
        'generator': {
            'author': gen_config.get('author', 'ruoyi'),
            'package_name': gen_config.get('package_name', 'com.ruoyi'),
            'output_path': GLOBAL_CONFIG.get('output_dir', './output'),
            'parent_menu_id': gen_config.get('parent_menu_id', 3),
            'gen_menu_sql': True
        }
    }
    
    # 写入临时配置文件
    temp_config_path = '/tmp/ruoyi_gen_config.yaml'
    with open(temp_config_path, 'w') as f:
        yaml.dump(temp_config, f)
    
    generator = RuoYiGenerator(temp_config_path)
    
    for table in tables:
        print(f"\n{Fore.YELLOW}📄 生成: {table.table_name}")
        context = generator.generate_from_config(config_file)
    
    output_path = generator.config['generator']['output_path']
    print(f"\n{Fore.GREEN}✅ 代码生成完成: {os.path.abspath(output_path)}")
    return output_path


def generate_code_from_config(config_file: str, schema_file: str = None) -> str:
    """从配置文件生成代码"""
    print(f"{Fore.BLUE}📖 从配置文件生成代码: {config_file}")
    
    gen_config = GLOBAL_CONFIG.get('generator', {})
    
    # 创建临时配置
    import yaml
    temp_config = {
        'database': get_db_config(),
        'generator': {
            'author': gen_config.get('author', 'ruoyi'),
            'package_name': gen_config.get('package_name', 'com.ruoyi'),
            'output_path': GLOBAL_CONFIG.get('output_dir', './output'),
            'parent_menu_id': gen_config.get('parent_menu_id', 3),
            'gen_menu_sql': True
        }
    }
    
    # 写入临时配置文件
    temp_config_path = '/tmp/ruoyi_gen_config.yaml'
    with open(temp_config_path, 'w') as f:
        yaml.dump(temp_config, f)
    
    generator = RuoYiGenerator(temp_config_path)
    
    # 从配置文件生成代码
    context = generator.generate_from_config(config_file)
    
    if not context:
        print(f"{Fore.RED}❌ 代码生成失败")
        return None
    
    output_path = generator.config['generator']['output_path']
    
    # 生成字典 SQL（如果有原始 schema 文件）
    if schema_file and os.path.exists(schema_file):
        parser = SchemaParser()
        tables = parser.parse_yaml(schema_file)
        if tables and tables[0].dicts:
            print(f"\n{Fore.YELLOW}📚 生成字典 SQL...")
            generate_dict_sql_files(tables[0], output_path)
    
    print(f"\n{Fore.GREEN}✅ 代码生成完成: {os.path.abspath(output_path)}")
    return output_path


def generate_dict_sql_files(table, output_path: str, strategy: str = 'merge'):
    """生成字典 SQL 文件"""
    from generator.dict_manager import DictManager
    
    db_config = get_db_config()
    dict_manager = DictManager(db_config)
    
    sql_dir = os.path.join(output_path, table.table_name, 'sql')
    os.makedirs(sql_dir, exist_ok=True)
    
    for dict_item in table.dicts:
        # 生成 DictConfig
        dict_config = dict_manager.generate_dict_config({
            'dict_type': dict_item.dict_type,
            'dict_name': dict_item.dict_name,
            'data': [
                {
                    'label': d.label,
                    'value': d.value,
                    'sort': d.sort,
                    'is_default': d.is_default,
                    'list_class': d.list_class,
                    'status': d.status
                }
                for d in dict_item.data
            ]
        }, table.table_name)
        
        # 生成 SQL
        sql_content = dict_manager.generate_dict_sql(dict_config, strategy)
        
        # 保存 SQL 文件
        sql_file = os.path.join(sql_dir, f"dict_{dict_item.dict_type}.sql")
        with open(sql_file, 'w', encoding='utf-8') as f:
            f.write(sql_content)
        
        print(f"   ✅ 字典 SQL: {sql_file}")
    
    dict_manager.close()
    print(f"{Fore.YELLOW}💡 部署时可选择是否执行字典 SQL")


# ============================================
# 主函数
# ============================================

def main():
    parser = argparse.ArgumentParser(
        description='若依代码生成器 - 一体化版本',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
一体化工作流:
  # 步骤1: 生成配置文件
  %(prog)s --schema configs/schemas/test-mvp2.yaml --step=config

  # 步骤2: 建表
  %(prog)s --schema configs/schemas/test-mvp2.yaml --step=create

  # 步骤3: 生成代码
  %(prog)s --schema configs/generated/mvp2_test-config.yaml --step=generate

  # 一键完成（自动读取 configs/ruoyi-generator.yaml）
  %(prog)s --schema configs/schemas/test-mvp2.yaml --step=all

传统工作流:
  # 从已有表生成代码
  %(prog)s -t customer_info -m customer
        """
    )
    
    # 一体化模式
    parser.add_argument(
        '--schema',
        help='表结构定义YAML文件路径（一体化模式）'
    )
    
    # 传统模式
    parser.add_argument(
        '-t', '--tables',
        help='数据库表名，多个表用逗号分隔'
    )
    
    parser.add_argument(
        '-m', '--module',
        help='模块名（如: customer, product）'
    )
    
    parser.add_argument(
        '-b', '--business',
        help='业务名（如: info, manage）'
    )
    
    # 通用选项
    parser.add_argument(
        '-c', '--config',
        default='configs/ruoyi-generator.yaml',
        help='全局配置文件路径 (默认: configs/ruoyi-generator.yaml)'
    )
    
    parser.add_argument(
        '--step',
        choices=['config', 'create', 'generate', 'all'],
        default='all',
        help='执行步骤: config=生成配置文件, create=建表, generate=生成代码, all=全部'
    )
    
    parser.add_argument(
        '-o', '--output',
        help='输出目录'
    )
    
    parser.add_argument(
        '--deploy',
        action='store_true',
        help='自动部署到若依项目'
    )
    
    args = parser.parse_args()
    
    # 加载全局配置
    global GLOBAL_CONFIG
    GLOBAL_CONFIG = load_global_config(args.config)
    
    print_banner()
    
    # 检查参数
    if not args.schema and not args.tables:
        print(f"{Fore.RED}❌ 错误: 请提供 --schema 或 -t 参数")
        parser.print_help()
        return 1
    
    # 一体化模式
    if args.schema:
        if not os.path.exists(args.schema):
            print(f"{Fore.RED}❌ 表结构定义文件不存在: {args.schema}")
            return 1
        
        # 步骤1: 仅生成配置文件
        if args.step == 'config':
            config_file = generate_config_from_schema(args.schema)
            if config_file:
                print(f"\n{Fore.CYAN}🎉 配置文件生成完成！")
            return 0 if config_file else 1
        
        # 步骤2: 仅建表
        elif args.step == 'create':
            table_names, tables = create_tables_from_schema(args.schema)
            if table_names:
                print(f"\n{Fore.CYAN}🎉 表创建完成！")
            return 0 if table_names else 1
        
        # 步骤3: 仅生成代码
        elif args.step == 'generate':
            # 尝试找到原始 schema 文件（用于生成字典 SQL）
            schema_file = args.schema
            if 'generated' in args.schema:
                # 如果是生成的配置文件，尝试找原始 schema
                table_name = os.path.basename(args.schema).replace('-config.yaml', '')
                possible_schema = os.path.join(GLOBAL_CONFIG.get('schema_dir', 'configs/schemas'), f"{table_name}.yaml")
                if os.path.exists(possible_schema):
                    schema_file = possible_schema
            
            output_dir = generate_code(args.schema, schema_file=schema_file)
            return 0 if output_dir else 1
        
        # 步骤4: 全部执行
        else:  # args.step == 'all'
            # Step 1: 生成配置
            config_file = generate_config_from_schema(args.schema)
            if not config_file:
                print(f"{Fore.RED}❌ 配置文件生成失败")
                return 1
            
            # Step 2: 创建表
            table_names, tables = create_tables_from_schema(args.schema)
            if not table_names:
                print(f"{Fore.RED}❌ 没有表被创建")
                return 1
            
            # Step 3: 生成代码
            output_dir = generate_code(config_file, schema_file=args.schema)
            
            print(f"\n{Fore.CYAN}🎉 全部完成！")
            print(f"{Fore.YELLOW}💡 如需部署，请运行:")
            print(f"   ./scripts/deploy.sh {table_names[0]}")
    
    # 传统模式
    else:
        print(f"{Fore.RED}❌ 传统模式暂未适配全局配置")
        return 1
    
    return 0


if __name__ == '__main__':
    sys.exit(main())
