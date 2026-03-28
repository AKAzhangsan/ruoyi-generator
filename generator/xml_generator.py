#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
XML Mapper 生成器 - 直接字符串拼接，避免Jinja2冲突
完美复刻若依原生输出
"""

from datetime import datetime


def generate_mapper_xml(table_name, table_comment, class_name, module_name, 
                        business_name, package_name, columns, pk_column,
                        tpl_type='crud', tree_config=None):
    """
    生成MyBatis XML
    """
    
    # 基础信息
    class_name_lower = class_name[0].lower() + class_name[1:]
    namespace = f"{package_name}.{module_name}.mapper.{class_name}Mapper"
    
    # 过滤掉基础字段（create_by等自动填充字段）
    # remark除外，因为用户可以编辑
    base_fields = ['create_by', 'create_time', 'update_by', 'update_time']
    entity_columns = [c for c in columns if c['column_name'] not in base_fields]
    
    # 生成resultMap
    result_map_lines = []
    for col in columns:
        tag = "id" if col['is_pk'] else "result"
        result_map_lines.append(f'        <{tag} property="{col["java_field"]}" column="{col["column_name"]}" />')
    
    result_map = '\n'.join(result_map_lines)
    
    # 简写类名（用于resultMap type）
    short_class_name = class_name
    
    # 生成select列
    select_columns = ', '.join([c['column_name'] for c in columns])
    
    # 生成where条件
    where_conditions = []
    for col in columns:
        if col['java_type'] == 'String' and not col['is_pk']:
            where_conditions.append(f'''        <if test="{col['java_field']} != null and {col['java_field']} != ''">
            and {col['column_name']} like concat('%', #{{{col['java_field']}}}, '%')
        </if>''')
        elif not col['is_pk']:
            where_conditions.append(f'''        <if test="{col['java_field']} != null">
            and {col['column_name']} = #{{{col['java_field']}}}
        </if>''')
    
    where_clause = '\n'.join(where_conditions)
    
    # 树表排序
    order_by_clause = ''
    if tpl_type == 'tree':
        parent_code = tree_config.get('tree_parent_code', 'parent_id') if isinstance(tree_config, dict) else (tree_config.tree_parent_code if tree_config else 'parent_id')
        order_by_clause = f'\n        order by {parent_code}, order_num'
    
    # 生成insert trim
    insert_cols = []
    insert_vals = []
    for col in entity_columns:
        if col['column_name'] not in base_fields:
            insert_cols.append(f'            <if test="{col["java_field"]} != null">{col["column_name"]},</if>')
            insert_vals.append(f'            <if test="{col["java_field"]} != null">#{{{col["java_field"]}}},</if>')
    
    insert_columns = '\n'.join(insert_cols)
    insert_values = '\n'.join(insert_vals)
    
    # 生成update trim
    update_sets = []
    for col in entity_columns:
        if col['column_name'] not in base_fields and not col['is_pk']:
            update_sets.append(f'            <if test="{col["java_field"]} != null">{col["column_name"]} = #{{{col["java_field"]}}},</if>')
    
    update_clause = '\n'.join(update_sets)
    
    # 组装XML
    xml = f'''<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE mapper
        PUBLIC "-//mybatis.org//DTD Mapper 3.0//EN"
        "http://mybatis.org/dtd/mybatis-3-mapper.dtd">
<mapper namespace="{namespace}">

    <resultMap type="{short_class_name}" id="{class_name}Result">
{result_map}
    </resultMap>

    <sql id="select{class_name}Vo">
        select {select_columns} from {table_name}
    </sql>

    <select id="select{class_name}List" parameterType="{short_class_name}" resultMap="{class_name}Result">
        <include refid="select{class_name}Vo"/>
        <where>
{where_clause}
        </where>{order_by_clause}
    </select>

    <select id="select{class_name}By{pk_column['cap_java_field']}" parameterType="{pk_column['java_type']}" resultMap="{class_name}Result">
        <include refid="select{class_name}Vo"/>
        where {pk_column['column_name']} = #{{{pk_column['java_field']}}}
    </select>

    <insert id="insert{class_name}" parameterType="{short_class_name}" useGeneratedKeys="true" keyProperty="{pk_column['java_field']}">
        insert into {table_name}
        <trim prefix="(" suffix=")" suffixOverrides=",">
{insert_columns}
        </trim>
        <trim prefix="values (" suffix=")" suffixOverrides=",">
{insert_values}
        </trim>
    </insert>

    <update id="update{class_name}" parameterType="{short_class_name}">
        update {table_name}
        <trim prefix="SET" suffixOverrides=",">
{update_clause}
        </trim>
        where {pk_column['column_name']} = #{{{pk_column['java_field']}}}
    </update>

    <delete id="delete{class_name}By{pk_column['cap_java_field']}" parameterType="{pk_column['java_type']}">
        delete from {table_name} where {pk_column['column_name']} = #{{{pk_column['java_field']}}}
    </delete>

    <delete id="delete{class_name}By{pk_column['cap_java_field']}s" parameterType="String">
        delete from {table_name} where {pk_column['column_name']} in
        <foreach collection="array" item="{pk_column['java_field']}" open="(" separator="," close=")">
            #{{{pk_column['java_field']}}}
        </foreach>
    </delete>

</mapper>'''
    
    return xml


if __name__ == '__main__':
    # 测试
    columns = [
        {'column_name': 'customer_id', 'java_field': 'customerId', 'java_type': 'Long', 'is_pk': True},
        {'column_name': 'customer_name', 'java_field': 'customerName', 'java_type': 'String', 'is_pk': False},
        {'column_name': 'status', 'java_field': 'status', 'java_type': 'String', 'is_pk': False},
    ]
    pk = {'column_name': 'customer_id', 'java_field': 'customerId', 'cap_java_field': 'CustomerId', 'java_type': 'Long'}
    
    xml = generate_mapper_xml(
        'customer_info', '客户信息', 'CustomerInfo',
        'customer', 'info', 'com.ruoyi.customer',
        columns, pk
    )
    print(xml[:500])
    print("...")
    print("✅ XML生成成功")
