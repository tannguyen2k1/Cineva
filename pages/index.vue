<template>
  <div :class="styles.dashboardPage">
    <div :class="styles.pageHeader">
      <h2>Tổng quan hệ thống</h2>
      <el-button type="primary" icon="Refresh">Làm mới dữ liệu</el-button>
    </div>

    <el-row :gutter="24" :class="styles.statCards">
      <el-col :span="6">
        <el-card :class="styles.premiumCard" shadow="never">
          <div :class="styles.statHeader">
            <span class="title">Người dùng</span>
            <el-icon :class="[styles.icon, styles.userIcon]"><User /></el-icon>
          </div>
          <div :class="styles.statValue">1,248</div>
          <div :class="[styles.statFooter, styles.textSuccess]">
            <el-icon><TopRight /></el-icon>
            <span>+12% so với tháng trước</span>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card :class="styles.premiumCard" shadow="never">
          <div :class="styles.statHeader">
            <span class="title">Doanh thu</span>
            <el-icon :class="[styles.icon, styles.revenueIcon]"><Money /></el-icon>
          </div>
          <div :class="styles.statValue">$14,230</div>
          <div :class="[styles.statFooter, styles.textSuccess]">
            <el-icon><TopRight /></el-icon>
            <span>+8% so với tháng trước</span>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card :class="styles.premiumCard" shadow="never">
          <div :class="styles.statHeader">
            <span class="title">Tenants</span>
            <el-icon :class="[styles.icon, styles.tenantIcon]"><House /></el-icon>
          </div>
          <div :class="styles.statValue">42</div>
          <div :class="[styles.statFooter, styles.textWarning]">
            <el-icon><Right /></el-icon>
            <span>Không thay đổi</span>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card :class="styles.premiumCard" shadow="never">
          <div :class="styles.statHeader">
            <span class="title">Lỗi hệ thống</span>
            <el-icon :class="[styles.icon, styles.errorIcon]"><Warning /></el-icon>
          </div>
          <div :class="styles.statValue">3</div>
          <div :class="[styles.statFooter, styles.textDanger]">
            <el-icon><BottomRight /></el-icon>
            <span>-2% so với tuần trước</span>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <el-row :gutter="24" :class="styles.mt4">
      <el-col :span="16">
        <el-card :class="styles.premiumCard" shadow="never">
          <template #header>
            <div :class="styles.cardHeader">
              <span>Hoạt động gần đây</span>
            </div>
          </template>
          <el-timeline>
            <el-timeline-item timestamp="2026-07-23 14:20" placement="top" type="primary">
              <el-card shadow="hover">
                <h4>Hệ thống tự động sao lưu</h4>
                <p>Sao lưu dữ liệu thành công vào Amazon S3</p>
              </el-card>
            </el-timeline-item>
            <el-timeline-item timestamp="2026-07-23 10:00" placement="top" type="success">
              <el-card shadow="hover">
                <h4>Admin đã đăng nhập</h4>
                <p>Tài khoản admin vừa đăng nhập từ địa chỉ IP 192.168.1.1</p>
              </el-card>
            </el-timeline-item>
            <el-timeline-item timestamp="2026-07-22 18:30" placement="top" type="warning">
              <el-card shadow="hover">
                <h4>Cập nhật phiên bản mới</h4>
                <p>Cập nhật template lên v2.0 thành công</p>
              </el-card>
            </el-timeline-item>
          </el-timeline>
        </el-card>
      </el-col>

      <el-col :span="8">
        <el-card :class="styles.premiumCard" shadow="never">
          <template #header>
            <div :class="styles.cardHeader">
              <span>Trạng thái máy chủ</span>
            </div>
          </template>
          <div class="server-status">
            <div :class="styles.statusItem">
              <div :class="styles.statusInfo">
                <span>CPU Usage</span>
                <span>45%</span>
              </div>
              <el-progress :percentage="45" />
            </div>
            <div :class="[styles.statusItem, styles.mt3]">
              <div :class="styles.statusInfo">
                <span>RAM Usage</span>
                <span>78%</span>
              </div>
              <el-progress :percentage="78" status="warning" />
            </div>
            <div :class="[styles.statusItem, styles.mt3]">
              <div :class="styles.statusInfo">
                <span>Disk Space</span>
                <span>92%</span>
              </div>
              <el-progress :percentage="92" status="exception" />
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup lang="ts">
import { User, TopRight, Money, House, Right, Warning, BottomRight, Refresh } from '@element-plus/icons-vue';
import styles from './dashboard.module.scss';
</script>
