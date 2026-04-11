#!/usr/bin/env python3
"""
XLSX to CSV/JSON 转换工具
将 xlsx/ 目录下的 Excel 文件转换为 data/ 目录下的 CSV/JSON 文件供游戏读取

使用方法:
    python xlsx_to_csv.py

依赖:
    pip install pandas openpyxl
"""

import os
import pandas as pd

# 配置
XLSX_DIR = '../xlsx'       # Excel 源文件目录
OUTPUT_DIR = '../data'     # 输出目录
OUTPUT_FORMAT = ['csv', 'json']    # 输出格式: csv, json (可以同时输出)

def convert_all():
    """转换所有 xlsx 文件"""
    # 创建输出目录
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    # 获取所有 xlsx 文件
    xlsx_files = [f for f in os.listdir(XLSX_DIR) if f.endswith('.xlsx')]
    
    if not xlsx_files:
        print(f"⚠️  在 {XLSX_DIR} 目录下没有找到 .xlsx 文件")
        print("请把你的 Excel 文件放到 xlsx/ 目录下")
        return
    
    print(f"🔍 找到 {len(xlsx_files)} 个 Excel 文件，开始转换...\n")
    
    for fname in xlsx_files:
        base_name = os.path.splitext(fname)[0]
        xlsx_path = os.path.join(XLSX_DIR, fname)
        
        print(f"📖 读取: {fname}")
        
        try:
            # 读取 Excel，默认第一个 sheet
            df = pd.read_excel(xlsx_path)
            
            # 去掉空行
            df = df.dropna(how='all')
            
            # CSV 输出
            if 'csv' in OUTPUT_FORMAT:
                csv_path = os.path.join(OUTPUT_DIR, f"{base_name}.csv")
                df.to_csv(csv_path, index=False, encoding='utf-8-sig')
                print(f"   ✅ 输出 CSV: data/{base_name}.csv ({len(df)} 行)")
            
            # JSON 输出
            if 'json' in OUTPUT_FORMAT:
                json_path = os.path.join(OUTPUT_DIR, f"{base_name}.json")
                df.to_json(json_path, orient='records', force_ascii=False, indent=2)
                print(f"   ✅ 输出 JSON: data/{base_name}.json ({len(df)} 行)")
        
        except Exception as e:
            print(f"   ❌ 转换失败: {e}")
            continue
        
        print()
    
    print("🎉 全部转换完成！")
    print(f"\n输出目录: {os.path.abspath(OUTPUT_DIR)}")
    print("现在可以在 Godot 中读取这些文件了")


if __name__ == '__main__':
    # 切换到脚本所在目录
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    convert_all()
