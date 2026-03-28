#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
若依代码生成器 - 核心生成器
完美复刻若依原生生成器功能
"""

import os
import yaml
from datetime import datetime
from typing import Dict, List, Optional
from .db_reader import DatabaseReader, TableInfo, ColumnInfo
from .template_engine import RuoYiTemplateEngine, CodeFileWriter
from .xml_generator import generate_mapper_xml


class RuoYiGenerator:
    """若依代码生成器"""
    
    # 若依基础字段（不生成到实体中，但remark除外因为用户可以编辑）
    BASE_ENTITY_FIELDS = ['create_by', 'create_time', 'update_by', 'update_time']
    
    # 树形表基础字段（remark除外因为用户可以编辑）
    BASE_TREE_ENTITY_FIELDS = ['create_by', 'create_time', 'update_by', 'update_time', 
                                'parent_id', 'ancestors', 'order_num']
    
    def __init__(self, config_path: str = 'config.yaml'):
        # 加载配置
        with open(config_path, 'r', encoding='utf-8') as f:
            self.config = yaml.safe_load(f)
        
        # 初始化组件
        self.db_reader = DatabaseReader(
            host=self.config['database']['host'],
            port=self.config['database']['port'],
            database=self.config['database']['database'],
            user=self.config['database']['user'],
            password=self.config['database']['password'],
            charset=self.config['database'].get('charset', 'utf8mb4')
        )
        
        self.template_engine = RuoYiTemplateEngine(
            self.config['generator'].get('template_path', './templates')
        )
        
        self.writer = CodeFileWriter(
            self.config['generator'].get('output_path', './output')
        )
        
        self.author = self.config['generator']['author']
        self.package_name = self.config['generator']['package_name']
        
    def generate(self, table_name: str, module_name: Optional[str] = None,
                 business_name: Optional[str] = None, tpl_category: str = 'crud'):
        """
        生成代码
        
        Args:
            table_name: 数据库表名
            module_name: 模块名，如 customer
            business_name: 业务名，如 info
            tpl_category: 模板类型 crud/tree/sub
        """
        print(f"\n🚀 开始生成表: {table_name}")
        
        # 读取表信息
        with self.db_reader:
            table_info = self.db_reader.get_table_info(table_name)
        
        # 设置生成信息
        self._prepare_table_info(table_info, module_name, business_name, tpl_category)
        
        # 构建模板上下文
        context = self._build_context(table_info)
        
        # 生成后端代码
        self._generate_backend(context)
        
        # 生成前端代码
        self._generate_frontend(context)
        
        # 生成菜单SQL
        if self.config['generator'].get('gen_menu_sql', True):
            self._generate_menu_sql(context)
        
        print(f"✅ 生成完成: {table_info.class_name}")
        return context
    
    def _prepare_table_info(self, table_info: TableInfo, module_name: Optional[str],
                           business_name: Optional[str], tpl_category: str):
        """准备表生成信息"""
        # 从表名提取信息
        # 表名格式: sys_user, customer_info, order_detail
        parts = table_info.table_name.split('_')
        
        # 模块名（如没有指定，使用第一个非sys前缀）
        if not module_name:
            if len(parts) > 1 and parts[0] not in ['sys', 'system']:
                module_name = parts[0]
            else:
                module_name = self.config['generator'].get('module_name', 'system')
        table_info.module_name = module_name
        
        # 业务名（如没有指定，使用最后一个部分）
        if not business_name:
            if len(parts) > 1:
                business_name = parts[-1]
            else:
                business_name = 'info'
        table_info.business_name = business_name
        
        # 实体类名（去除表前缀，转驼峰）
        # sys_user -> SysUser, customer_info -> CustomerInfo
        if parts[0] in ['sys', 'system'] and len(parts) > 1:
            class_name_base = '_'.join(parts[1:])
        else:
            class_name_base = table_info.table_name
        
        table_info.class_name = self._to_pascal_case(class_name_base)
        table_info.classname = table_info.class_name[0].lower() + table_info.class_name[1:]
        
        # 功能名（从表注释提取，或使用类名）
        if table_info.table_comment:
            # 去除括号内容
            comment = table_info.table_comment.split('（')[0].split('(')[0]
            table_info.function_name = comment
        else:
            table_info.function_name = table_info.class_name
    
    def generate_from_config(self, config_path: str, output_subdir: str = None):
        """从配置文件生成代码
        
        Args:
            config_path: YAML配置文件路径
            output_subdir: 输出子目录名称（默认使用表名）
        """
        from .schema_parser import SchemaParser
        
        print(f"\n🚀 从配置文件生成代码: {config_path}")
        
        # 解析配置文件
        parser = SchemaParser()
        tables = parser.parse_yaml(config_path)
        
        if not tables:
            print("❌ 配置文件中没有表定义")
            return None
        
        table = tables[0]  # 处理第一个表
        
        # 创建独立输出目录
        if output_subdir is None:
            output_subdir = table.table_name
        
        output_base = self.config['generator'].get('output_path', './output')
        output_path = os.path.join(output_base, output_subdir)
        
        # 更新 writer 到新的输出路径
        old_writer = self.writer
        self.writer = CodeFileWriter(output_path)
        
        print(f"📁 输出目录: {os.path.abspath(output_path)}")
        
        # 构建上下文
        context = self._build_context_from_schema(table)
        
        # 生成后端代码
        self._generate_backend(context)
        
        # 生成前端代码
        self._generate_frontend(context)
        
        # 生成菜单SQL
        if self.config['generator'].get('gen_menu_sql', True):
            self._generate_menu_sql(context)
        
        # 恢复原来的 writer
        self.writer = old_writer
        
        print(f"✅ 生成完成: {table.gen_config.class_name}")
        return context
    
    def _build_context_from_schema(self, table) -> Dict:
        """从TableSchema构建模板上下文"""
        from .schema_parser import Column
        
        now = datetime.now()
        
        # 处理字段
        columns = []
        list_columns = []  # 列表显示字段
        edit_columns = []  # 编辑字段
        query_columns = []  # 查询字段
        insert_columns = []  # 插入字段
        
        for col in table.columns:
            # 确定Java类型：优先使用配置的java_type，否则根据类型推断
            java_type = col.java_type if col.java_type else self._get_java_type(col.type)
            
            col_dict = {
                'column_name': col.name,
                'column_comment': col.comment,
                'data_type': col.type,
                'java_field': col.name,  # 简化处理，实际需要下划线转驼峰
                'java_type': java_type,
                'jdbc_type': self._get_jdbc_type(col.type),
                'is_pk': col.is_pk,
                'is_increment': col.is_auto_increment,
                'is_nullable': 'YES' if col.is_nullable else 'NO',
                'column_default': col.default,
                
                # 数字精度（MVP2新增）
                'numeric_precision': col.precision if hasattr(col, 'precision') else None,
                'numeric_scale': col.scale if hasattr(col, 'scale') else None,
                
                # 从配置读取
                'is_insert': col.is_insert,
                'is_edit': col.is_edit,
                'is_list': col.is_list,
                'is_query': col.query,
                'is_required': col.is_required,
                'query_type': col.query_type,
                'component': col.component,
                'dict_type': col.dict_type,
                'date_format': col.date_format,
                # MVP3: 上传组件属性
                'limit': getattr(col, 'limit', None),
                'file_size': getattr(col, 'file_size', None),
                'height': getattr(col, 'height', None),
            }
            
            # 下划线转驼峰
            col_dict['java_field'] = self._to_camel_case(col.name)
            col_dict['cap_java_field'] = col_dict['java_field'][0].upper() + col_dict['java_field'][1:]
            
            columns.append(col_dict)
            
            if col_dict['is_list'] and col_dict['column_name'] not in [c['column_name'] for c in list_columns]:
                list_columns.append(col_dict)
            if col_dict['is_edit'] and col_dict['column_name'] not in [c['column_name'] for c in edit_columns]:
                edit_columns.append(col_dict)
            if col_dict['is_query'] and col_dict['column_name'] not in [c['column_name'] for c in query_columns]:
                query_columns.append(col_dict)
            if col_dict['is_insert'] and col_dict['column_name'] not in [c['column_name'] for c in insert_columns]:
                insert_columns.append(col_dict)
        
        # 找到主键列
        pk_column = None
        for col in columns:
            if col['is_pk']:
                pk_column = col
                break
        
        # 添加 BaseEntity 的字段（用于SQL生成，但不在Entity类中生成字段定义）
        # 注意：remark已从BaseEntity中移除，如果需要应在YAML中显式定义
        base_entity_columns = [
            {
                'column_name': 'create_time',
                'column_comment': '创建时间',
                'data_type': 'datetime',
                'java_field': 'createTime',
                'java_type': 'Date',
                'jdbc_type': 'TIMESTAMP',
                'is_pk': False,
                'is_increment': False,
                'is_nullable': True,
                'column_default': None,
                'is_insert': False,  # 自动填充
                'is_edit': False,
                'is_list': True,
                'is_query': True,
                'is_required': False,
                'query_type': 'BETWEEN',
                'component': 'DatePicker',
                'dict_type': None,
                'date_format': 'yyyy-MM-dd HH:mm:ss',
            }
        ]
        
        # 检查是否已在 columns 中，避免重复
        existing_names = {col['column_name'] for col in columns}
        for base_col in base_entity_columns:
            if base_col['column_name'] not in existing_names:
                columns.append(base_col)
                if base_col['is_list'] and base_col['column_name'] not in [c['column_name'] for c in list_columns]:
                    list_columns.append(base_col)
                if base_col['is_edit'] and base_col['column_name'] not in [c['column_name'] for c in edit_columns]:
                    edit_columns.append(base_col)
                if base_col['is_query'] and base_col['column_name'] not in [c['column_name'] for c in query_columns]:
                    query_columns.append(base_col)
                if base_col['is_insert'] and base_col['column_name'] not in [c['column_name'] for c in insert_columns]:
                    insert_columns.append(base_col)
        
        context = {
            # 基础信息
            'tableName': table.table_name,
            'table_comment': table.table_comment,
            'functionName': table.gen_config.function_name,
            'ClassName': table.gen_config.class_name,
            'className': table.gen_config.class_name[0].lower() + table.gen_config.class_name[1:],
            'moduleName': table.module,
            'businessName': table.business,
            'BusinessName': table.business.capitalize(),
            'packageName': f"{self.package_name}.{table.module}",
            'basePackage': self.package_name,
            'author': table.gen_config.author,
            'datetime': now.strftime('%Y-%m-%d'),
            'year': now.year,

            # 字段信息
            'columns': columns,
            'list_columns': list_columns,
            'edit_columns': edit_columns,
            'query_columns': query_columns,
            'insert_columns': insert_columns,
            'pkColumn': pk_column,

            # 权限前缀
            'permissionPrefix': f"{table.module}:{table.business}",

            # 上级菜单ID
            'parentMenuId': self.config['generator'].get('parent_menu_id', '3'),

            # 菜单排序号
            'sort': getattr(table.gen_config, 'sort', 1) if hasattr(table, 'gen_config') else 1,

            # 模板类型
            'tpl_type': table.tpl_type if hasattr(table, 'tpl_type') else 'crud',
            'tree_config': table.tree_config if hasattr(table, 'tree_config') else None,
            # 树表字段的驼峰格式（前端JSON使用驼峰）
            'tree_code_camel': self._to_camel_case(table.tree_config.tree_code) if (hasattr(table, 'tree_config') and table.tree_config) else 'id',
            'tree_parent_code_camel': self._to_camel_case(table.tree_config.tree_parent_code) if (hasattr(table, 'tree_config') and table.tree_config) else 'parentId',
            'tree_name_camel': self._to_camel_case(table.tree_config.tree_name) if (hasattr(table, 'tree_config') and table.tree_config) else 'name',

            # 模板web类型
            'tpl_web_type': table.gen_config.tpl_web_type if hasattr(table, 'gen_config') else 'element-plus',
            
            # 主子表配置
            'sub_table': table.sub_table if hasattr(table, 'sub_table') else None,
        }
        
        # 主子表上下文补充
        if context.get('tpl_type') == 'sub' and context.get('sub_table'):
            sub = context['sub_table']
            sub_class_name = self._to_pascal_case(sub.table_name)
            sub_class_name_lower = sub_class_name[0].lower() + sub_class_name[1:]
            fk_camel = self._to_camel_case(sub.fk_column)
            fk_cap = fk_camel[0].upper() + fk_camel[1:]
            
            # 构建子表字段列表
            sub_columns = []
            for col in sub.columns:
                col_dict = {
                    'column_name': col.name,
                    'java_field': self._to_camel_case(col.name),
                    'java_type': col.java_type or 'String',
                    'column_comment': col.comment or col.name,
                    'is_pk': col.is_pk,
                    'is_required': col.is_required,
                    'dict_type': col.dict_type,
                    'component': col.component,
                    'date_format': col.date_format,
                    'length': col.length,
                    'numeric_scale': col.scale,
                }
                sub_columns.append(col_dict)
            
            context['sub_context'] = {
                'subClassName': sub_class_name,
                'subclassName': sub_class_name_lower,
                'subTableName': sub.table_name,
                'subTableComment': sub.table_comment,
                'subFkName': sub.fk_column,
                'subFkJavaField': fk_camel,
                'subFkCap': fk_cap,
                'sub_columns': sub_columns,
            }
            # 快捷变量
            sc = context['sub_context']
            context['subTableName'] = sc['subTableName']
            context['subTableComment'] = sc['subTableComment']
            context['subFkName'] = sc['subFkName']
            context['subFkJavaField'] = sc['subFkJavaField']
            context['subFkCap'] = sc['subFkCap']
            context['sub_columns'] = sc['sub_columns']
            context['subClassName'] = sc['subClassName']
            context['subclassName'] = sc['subclassName']

        return context
    
    def _get_java_type(self, data_type: str) -> str:
        """获取Java类型"""
        type_mapping = {
            'bigint': 'Long',
            'int': 'Integer',
            'tinyint': 'Integer',
            'smallint': 'Integer',
            'varchar': 'String',
            'char': 'String',
            'text': 'String',
            'longtext': 'String',
            'decimal': 'BigDecimal',
            'float': 'Float',
            'double': 'Double',
            'datetime': 'Date',
            'timestamp': 'Date',
            'date': 'Date',
            'blob': 'byte[]',
        }
        return type_mapping.get(data_type, 'String')
    
    def _get_jdbc_type(self, data_type: str) -> str:
        """获取JDBC类型"""
        type_mapping = {
            'bigint': 'BIGINT',
            'int': 'INTEGER',
            'tinyint': 'TINYINT',
            'smallint': 'SMALLINT',
            'varchar': 'VARCHAR',
            'char': 'CHAR',
            'text': 'LONGVARCHAR',
            'decimal': 'DECIMAL',
            'datetime': 'TIMESTAMP',
            'timestamp': 'TIMESTAMP',
            'date': 'DATE',
        }
        return type_mapping.get(data_type, 'VARCHAR')
    
    def _to_camel_case(self, snake_str: str) -> str:
        """下划线转驼峰"""
        components = snake_str.split('_')
        return components[0] + ''.join(x.title() for x in components[1:])

    def _build_context(self, table_info: TableInfo) -> Dict:
        """构建模板上下文"""
        now = datetime.now()
        
        # 处理字段
        columns = []
        list_columns = []  # 列表显示字段
        edit_columns = []  # 编辑字段
        query_columns = []  # 查询字段
        
        for col in table_info.columns:
            col_dict = col.to_dict()
            
            # 判断是否为基类字段
            col_dict['is_base'] = col.column_name in self.BASE_ENTITY_FIELDS
            
            # 判断是否在列表显示（非大字段、非敏感字段）
            col_dict['list'] = not col_dict['is_base'] and col.data_type not in ['text', 'longtext', 'blob']
            
            # 判断是否可编辑（非主键、非自增）
            col_dict['edit'] = not col.is_pk or not col.is_increment
            
            # 判断是否可查询（字符串类型）
            col_dict['query'] = col.data_type in ['varchar', 'char'] and col_dict['list']
            col_dict['query_type'] = 'LIKE' if col_dict['query'] else '='
            
            columns.append(col_dict)
            
            if col_dict['list']:
                list_columns.append(col_dict)
            if col_dict['edit']:
                edit_columns.append(col_dict)
            if col_dict['query']:
                query_columns.append(col_dict)
        
        context = {
            # 基础信息
            'tableName': table_info.table_name,
            'table_comment': table_info.table_comment,
            'functionName': table_info.function_name,
            'ClassName': table_info.class_name,
            'className': table_info.classname,
            'moduleName': table_info.module_name,
            'businessName': table_info.business_name,
            'BusinessName': table_info.business_name.capitalize(),
            'packageName': f"{self.package_name}.{table_info.module_name}",
            'basePackage': self.package_name,
            'author': self.author,
            'datetime': now.strftime('%Y-%m-%d'),
            'year': now.year,
            
            # 字段信息
            'columns': columns,
            'list_columns': list_columns,
            'edit_columns': edit_columns,
            'query_columns': query_columns,
            'pkColumn': table_info.pk_column.to_dict() if table_info.pk_column else None,
            
            # 权限前缀
            'permissionPrefix': f"{table_info.module_name}:{table_info.business_name}",
            
            # 上级菜单ID
            'parentMenuId': self.config['generator'].get('parent_menu_id', '3'),
            
            # 菜单排序号
            'sort': table.gen_config.sort if hasattr(table.gen_config, 'sort') else 1,
        }
        
        return context
    
    def _generate_backend(self, context: Dict):
        """生成后端代码"""
        module = context['moduleName']
        class_name = context['ClassName']
        business = context['businessName']
        
        # 1. Entity
        content = self.template_engine.render('java/entity.java.j2', context)
        self.writer.write(
            f"main/java/{self.package_name.replace('.', '/')}/{module}/domain/{class_name}.java",
            content
        )
        print(f"  ✓ Entity: {class_name}.java")
        
        # 1.1 子表 Entity（主子表模式）
        if context.get('tpl_type') == 'sub' and context.get('sub_context'):
            sub_class = context['sub_context']['subClassName']
            sub_context = {**context, **context['sub_context']}
            content = self.template_engine.render('java/sub-entity.java.j2', sub_context)
            self.writer.write(
                f"main/java/{self.package_name.replace('.', '/')}/{module}/domain/{sub_class}.java",
                content
            )
            print(f"  ✓ Sub Entity: {sub_class}.java")
        
        # 2. Mapper接口
        content = self.template_engine.render('java/mapper.java.j2', context)
        self.writer.write(
            f"main/java/{self.package_name.replace('.', '/')}/{module}/mapper/{class_name}Mapper.java",
            content
        )
        print(f"  ✓ Mapper: {class_name}Mapper.java")
        
        # 3. Service接口
        content = self.template_engine.render('java/service.java.j2', context)
        self.writer.write(
            f"main/java/{self.package_name.replace('.', '/')}/{module}/service/I{class_name}Service.java",
            content
        )
        print(f"  ✓ Service: I{class_name}Service.java")
        
        # 4. Service实现
        content = self.template_engine.render('java/serviceImpl.java.j2', context)
        self.writer.write(
            f"main/java/{self.package_name.replace('.', '/')}/{module}/service/impl/{class_name}ServiceImpl.java",
            content
        )
        print(f"  ✓ ServiceImpl: {class_name}ServiceImpl.java")
        
        # 5. Controller
        content = self.template_engine.render('java/controller.java.j2', context)
        self.writer.write(
            f"main/java/com/ruoyi/web/controller/{module}/{class_name}Controller.java",
            content
        )
        print(f"  ✓ Controller: {class_name}Controller.java")
        
        # 6. Mapper XML (使用原生Python生成，避免Jinja2冲突)
        xml_content = generate_mapper_xml(
            table_name=context['tableName'],
            table_comment=context['table_comment'],
            class_name=context['ClassName'],
            module_name=context['moduleName'],
            business_name=context['businessName'],
            package_name=context['basePackage'],  # 使用 basePackage 而不是 packageName
            columns=context['columns'],
            pk_column=context['pkColumn'],
            tpl_type=context.get('tpl_type', 'crud'),
            tree_config=context.get('tree_config')
        )
        self.writer.write(
            f"main/resources/mapper/{module}/{class_name}Mapper.xml",
            xml_content
        )
        print(f"  ✓ Mapper XML: {class_name}Mapper.xml")
    
    def _generate_frontend(self, context: Dict):
        """生成前端代码"""
        module = context['moduleName']
        business = context['businessName']
        class_name = context['className']

        # 1. API
        content = self.template_engine.render('vue/api.js.j2', context)
        self.writer.write(
            f"vue/api/{module}/{business}.js",
            content
        )
        print(f"  ✓ API: {module}/{business}.js")

        # 2. Vue页面 - 根据 tpl_type 选择模板
        tpl_type = context.get('tpl_type', 'crud')
        if tpl_type == 'tree':
            vue_template = 'vue/index-tree.vue.j2'
        elif tpl_type == 'sub':
            vue_template = 'vue/index-sub.vue.j2'
        else:
            vue_template = 'vue/index.vue.j2'

        content = self.template_engine.render(vue_template, context)
        self.writer.write(
            f"vue/views/{module}/{business}/index.vue",
            content
        )
        print(f"  ✓ Vue: views/{module}/{business}/index.vue")
    
    def _generate_menu_sql(self, context: Dict):
        """生成菜单SQL"""
        content = self.template_engine.render('sql/menu.sql.j2', context)
        self.writer.write(
            f"sql/{context['tableName']}_menu.sql",
            content
        )
        print(f"  ✓ Menu SQL: {context['tableName']}_menu.sql")
    
    @staticmethod
    def _to_pascal_case(snake_str: str) -> str:
        """下划线转驼峰（首字母大写）"""
        if not snake_str:
            return ''
        return ''.join(x.capitalize() for x in snake_str.split('_'))


if __name__ == '__main__':
    gen = RuoYiGenerator()
    gen.generate('customer_info', module_name='customer')
