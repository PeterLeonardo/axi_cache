#===============================
## To be modified ##
DIRS ?= vsrc/axi vsrc/mem testbench #directories
USER_FILES ?= ./GitCommit.mk ./vivado_recreate.tcl ./hw/project_1/recreate_project.tcl ./hw/project_1/project_1.srcs/sources_1/ip/data_col_mem/data_col_mem.xci ./hw/project_1/project_1.srcs/sources_1/ip/tagv_col_mem/tagv_col_mem.xci #single file

#===============================
# 自动发现文件
AUTO_V_FILES := $(foreach dir,$(DIRS),$(wildcard $(dir)/*.v))
AUTO_SV_FILES := $(foreach dir,$(DIRS),$(wildcard $(dir)/*.sv))
AUTO_SVH_FILES := $(foreach dir,$(DIRS),$(wildcard $(dir)/*.svh))

AUTO_FILES := $(AUTO_V_FILES) $(AUTO_SV_FILES) $(AUTO_SVH_FILES)

ALL_FILES := $(USER_FILES) $(AUTO_V_FILES) $(AUTO_SV_FILES) $(AUTO_SVH_FILES)
BUILD_TIMESTAMP := $(shell powershell -Command "Get-Date -Format 'yyyyMMdd_HHmmss'")

.PHONY: all GitCommit listfiles GitCommitFast GitInit GitRemotePush

all : listfiles GitCommit

# 列出所有将被处理的文件
listfiles:
	@echo "Directories: $(DIRS)"
	@echo "User files: $(USER_FILES)"
	@echo "Auto-discovered files:"
	@for file in $(AUTO_FILES); do \
		echo "  $$file"; \
	done
	@echo "Total files: $(words $(ALL_FILES))"

# Git 提交目标
GitCommit: listfiles
	@echo "=== Preparing Git Commit ==="
	@echo "Timestamp: $(BUILD_TIMESTAMP)"
	
# 检查是否有变更
	@if [ -z "$$(git status --porcelain $(ALL_FILES))" ]; then \
		echo "No changes in specified files to commit"; \
		exit 0; \
	fi
	
# 显示将要添加的文件
	@echo "Files to be added:"
	@git status --short $(ALL_FILES)
	
# 确认操作
	@echo -n "Proceed with commit? [y/N] " && read ans && [ $${ans:-N} = y ]
	
# 执行提交
	@echo "Adding files..."
	@git add $(ALL_FILES)
	@git commit -m "Update: $(BUILD_TIMESTAMP)"
	
	@echo "=== Commit Completed ==="
	@echo "Commit timestamp: $(BUILD_TIMESTAMP)"

# 简化的快速提交（无需确认）
GitCommitFast:
	@git add $(ALL_FILES)
	@git commit -m "Quick commit: $(BUILD_TIMESTAMP)"
	@echo "Quick commit done: $(BUILD_TIMESTAMP)"

GitInit:
	git init
	git branch -M main
	git remote add origin https://github.com/PeterLeonardo/axi_cache.git

GitRemotePush:
	git push -u origin main