#!/usr/bin/env python3
"""
将 xlsx/ 目录下的 csv 模板转成 xlsx
方便你直接用 Excel 打开编辑
"""

import os
import pandas as pd

XLSX_DIR = '../xlsx'

def convert_all_csv_to_xlsx():
    csv_files = [f for f in os.listdir(XLSX_DIR) if f.endswith('.csv')]
    
    for fname in csv_files:
        base_name = os.path.splitext(fname)[0]
        csv_path = os.path.join(XLSX_DIR, fname)
        xlsx_path = os.path.join(XLSX_DIR, f"{base_name}.xlsx")
        
        print(f"转换 {fname} -> {base_name}.xlsx")
        df = pd.read_csv(csv_path)
        df.to_excel(xlsx_path, index=False, engine='openpyxl')
        print(f"  完成: {xlsx_path}")
    
    print("\n🎉 全部转换完成！现在你可以直接在 Excel 中编辑 .xlsx 文件了")

if __name__ == '__main__':
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    convert_all_csv_to_xlsx()
