顺序写入
python cache_instruction_generator.py -n 10 -o instructions.txt
随机读写操作
python cache_instruction_generator.py -n 20 -o random_ops.txt --random-rdwr
完全随机
python cache_instruction_generator.py -n 50 -o fully_random.txt --random-rdwr --random-addr --random-data --random-mask
自定义参数
python cache_instruction_generator.py -n 100 -o custom.txt \
  --random-rdwr \
  --default-mask 1101 \
  --start-address 0x1000 \
  --addr-increment 4
查看帮助
python cache_instruction_generator.py -h