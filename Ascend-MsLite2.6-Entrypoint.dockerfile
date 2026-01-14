# ============================================================================
# 基于已构建好的 ai-guardrail:v1 镜像，添加启动脚本入口
# 基础镜像：ai-guardrail:v1 (需先在本地构建完成)
# ============================================================================
FROM ai-guardrail:v1

# 复制启动脚本到系统路径
COPY start.sh /usr/local/bin/start.sh

# 赋予执行权限
RUN chmod +x /usr/local/bin/start.sh

# 设置工作目录
WORKDIR /workspace

# 设置 ENTRYPOINT
# 容器启动时会先执行 start.sh，然后再执行 CMD 命令
ENTRYPOINT ["/usr/local/bin/start.sh"]

# 默认命令 (如果 docker run 没有指定命令，则执行 bash)
CMD ["bash"]
