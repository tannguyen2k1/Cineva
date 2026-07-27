<template>
  <div :class="styles.page">
    <div :class="styles.toolbar">
      <div :class="styles.toolbarMeta">
        <span :class="styles.roleName">{{ roleName || '…' }}</span>
        <span :class="styles.dot" aria-hidden="true" />
        <span :class="styles.toolbarHint">Phân quyền</span>
      </div>
      <div :class="styles.toolbarActions">
        <el-button type="primary" :loading="saving" @click="onSave">Lưu</el-button>
      </div>
    </div>

    <el-alert
      v-if="error"
      type="error"
      :title="error"
      show-icon
      :class="styles.alert"
      closable
      @close="error = ''"
    />

    <div v-loading="loading" :class="styles.workspace">
      <aside :class="styles.modules">
        <button
          v-for="group in permissionGroups"
          :key="group.resource"
          type="button"
          :class="[
            styles.moduleItem,
            activeTab === group.resource ? styles.moduleItemActive : ''
          ]"
          @click="activeTab = group.resource"
        >
          <span :class="styles.moduleLabel">{{ group.label }}</span>
          <span :class="styles.moduleCount">
            {{ selectedCount(group) }}/{{ group.permissions.length }}
          </span>
        </button>
      </aside>

      <section v-if="activeGroup" :class="styles.content">
        <div :class="styles.contentHead">
          <h3 :class="styles.contentTitle">{{ activeGroup.label }}</h3>
          <el-button link type="primary" @click="toggleGroup(activeGroup)">
            {{ isGroupFullySelected(activeGroup) ? 'Bỏ chọn' : 'Chọn hết' }}
          </el-button>
        </div>

        <ul :class="styles.permList">
          <li
            v-for="perm in activeGroup.permissions"
            :key="perm.id"
            :class="styles.permRow"
            @click="togglePerm(perm.id, !selectedIds.includes(perm.id))"
          >
            <el-checkbox
              :model-value="selectedIds.includes(perm.id)"
              @click.stop
              @change="(val: string | number | boolean) => togglePerm(perm.id, Boolean(val))"
            />
            <div :class="styles.permText">
              <span :class="styles.permAction">{{ perm.actionLabel }}</span>
              <span v-if="perm.description" :class="styles.permDesc">{{ perm.description }}</span>
            </div>
          </li>
        </ul>
      </section>
    </div>
  </div>
</template>

<script setup lang="ts">
import styles from './permissions.module.scss';
import { ref, computed, onMounted } from 'vue';
import { ElMessage } from 'element-plus';
import { useAuthStore } from '~/stores/auth';

interface PermissionItem {
  id: string;
  action: string;
  actionLabel: string;
  key: string;
  description: string | null;
}

interface PermissionGroup {
  resource: string;
  label: string;
  permissions: PermissionItem[];
}

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();

const roleId = computed(() => String(route.params.id || ''));

const loading = ref(false);
const saving = ref(false);
const error = ref('');
const roleName = ref('');
const permissionGroups = ref<PermissionGroup[]>([]);
const selectedIds = ref<string[]>([]);
const activeTab = ref('');

const activeGroup = computed(
  () => permissionGroups.value.find(g => g.resource === activeTab.value) || null
);

const authHeaders = () => {
  const headers: Record<string, string> = {};
  if (authStore.token) headers.Authorization = `Bearer ${authStore.token}`;
  if (authStore.tenant_id) headers['x-tenant-id'] = authStore.tenant_id;
  return headers;
};

const selectedCount = (group: PermissionGroup) =>
  group.permissions.filter(p => selectedIds.value.includes(p.id)).length;

const isGroupFullySelected = (group: PermissionGroup) =>
  group.permissions.length > 0 &&
  group.permissions.every(p => selectedIds.value.includes(p.id));

const toggleGroup = (group: PermissionGroup) => {
  const ids = group.permissions.map(p => p.id);
  if (isGroupFullySelected(group)) {
    selectedIds.value = selectedIds.value.filter(id => !ids.includes(id));
  } else {
    selectedIds.value = Array.from(new Set([...selectedIds.value, ...ids]));
  }
};

const togglePerm = (id: string, checked: boolean) => {
  if (checked) {
    if (!selectedIds.value.includes(id)) {
      selectedIds.value = [...selectedIds.value, id];
    }
  } else {
    selectedIds.value = selectedIds.value.filter(x => x !== id);
  }
};

const goBack = () => router.push('/systems/roles');

const load = async () => {
  if (!roleId.value) {
    error.value = 'Thiếu id vai trò';
    return;
  }

  loading.value = true;
  error.value = '';
  try {
    const [permsRes, assignedRes] = await Promise.all([
      $fetch<any>('/api/permissions', { headers: authHeaders() }),
      $fetch<any>(`/api/roles/${roleId.value}/permissions`, { headers: authHeaders() })
    ]);

    permissionGroups.value = permsRes?.data || [];
    selectedIds.value = assignedRes?.data?.permissionIds || [];
    roleName.value = assignedRes?.data?.roleName || 'Vai trò';
    activeTab.value = permissionGroups.value[0]?.resource || '';
  } catch (err: any) {
    error.value = err?.data?.statusMessage || err?.message || 'Không tải được phân quyền';
  } finally {
    loading.value = false;
  }
};

const onSave = async () => {
  saving.value = true;
  try {
    await $fetch(`/api/roles/${roleId.value}/permissions`, {
      method: 'PUT',
      body: { permissionIds: selectedIds.value },
      headers: authHeaders()
    });
    ElMessage.success('Đã lưu phân quyền');
    await router.push('/systems/roles');
  } catch (err: any) {
    ElMessage.error(err?.data?.statusMessage || err?.message || 'Không thể lưu phân quyền');
  } finally {
    saving.value = false;
  }
};

onMounted(() => load());
usePageRefresh(() => load());
</script>
