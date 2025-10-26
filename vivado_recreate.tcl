set outdir ./
file mkdir $outdir

# 工程目录（2023.2 有 DIRECTORY 属性）
set projdir [get_property DIRECTORY [current_project]]
if {$projdir eq ""} { set projdir [pwd] }

# 关键：-use_bd_files 与 -no_copy_sources 搭配
write_project_tcl -force -all_properties -use_bd_files -no_copy_sources \
  -paths_relative_to $projdir \
  $outdir/recreate_project.tcl

# 可选：导出自定义 IP 仓库重定向脚本
set iprepos [get_property ip_repo_paths [current_project]]
if {[llength $iprepos]} {
  set fp [open "$outdir/ip_repo_paths.tcl" w]
  puts $fp {# Repoint custom IP repositories after creating/opening the project}
  foreach p $iprepos {
    puts $fp "set_property ip_repo_paths \[concat \[get_property ip_repo_paths \[current_project\]\] {$p}] \[current_project\]"
  }
  puts $fp "update_ip_catalog"
  close $fp
}

# 可选：记录信息
set fp [open "$outdir/target_info.txt" w]
puts $fp "VIVADO: [version -short]"
puts $fp "PART:   [get_property PART [current_project]]"
puts $fp "BOARD:  [get_property BOARD_PART [current_project]]"
close $fp