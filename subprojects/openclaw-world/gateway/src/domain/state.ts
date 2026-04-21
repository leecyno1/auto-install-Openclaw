import { EQUIPMENT_CATALOG, ROLE_IDS, ROLE_PROFILES, type BuildState, type EquipmentSlotId, type RoleId } from '../../../shared/world-model.js';

export { ROLE_IDS };

const ROLE_ALIASES: Record<string, RoleId> = {
  druid: 'druid',
  generalist: 'druid',
  wanjinyou: 'druid',
  assassin: 'assassin',
  analyst: 'assassin',
  mage: 'mage',
  researcher: 'mage',
  summoner: 'summoner',
  manager: 'summoner',
  warrior: 'warrior',
  technician: 'warrior',
  paladin: 'paladin',
  marketer: 'paladin',
  designer: 'designer',
  archer: 'designer',
};

export function normalizeRoleId(input: string | null | undefined): RoleId {
  const key = String(input || '').trim().toLowerCase();
  return ROLE_ALIASES[key] || 'druid';
}

function defaultEquipmentSlots(roleId: RoleId): Partial<Record<EquipmentSlotId, string>> {
  const slots = { ...ROLE_PROFILES[roleId].starterEquipment };
  if (!slots.chest) {
    slots.chest = 'minimax-2-7';
  }
  return slots;
}

function reserveEquipmentInventory(roleId: RoleId): string[] {
  const equippedIds = new Set(Object.values(defaultEquipmentSlots(roleId)).filter(Boolean));
  return EQUIPMENT_CATALOG.filter((item) => !equippedIds.has(item.id)).map((item) => item.id);
}

export function createDefaultBuildState(inputRoleId: string | null | undefined): BuildState {
  const roleId = normalizeRoleId(inputRoleId);
  const role = ROLE_PROFILES[roleId];
  return {
    roleId,
    draftDirty: false,
    identity: {
      assistantName: 'Clawd',
      userName: '主人',
      region: '中国大陆',
      timezone: 'Asia/Shanghai',
      goal: role.description,
      personality: '严谨、务实、可协作',
      workStyle: '先分析再执行，阶段性回报',
    },
    routing: {
      modelRoute: role.recommendedModelRoute,
      tokenRule: roleId === 'druid' ? 'low' : 'medium',
      skillPack: roleId === 'druid' ? 'low' : 'medium',
      advancedModel: roleId === 'warrior' ? 'gpt-5.4' : 'claude-main',
    },
    skills: {
      installed: [...role.starterSkills],
      disabled: [],
      reserve: [],
    },
    equipment: {
      slots: defaultEquipmentSlots(roleId),
      inventory: reserveEquipmentInventory(roleId),
    },
    updatedAt: new Date().toISOString(),
  };
}
