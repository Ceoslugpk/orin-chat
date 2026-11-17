const countLabels = customRoles =>
  customRoles.reduce((counts, role) => {
    counts[role.name] = (counts[role.name] || 0) + 1;
    return counts;
  }, {});

const roleLabel = (role, labelCounts, t) => {
  if (labelCounts[role.name] < 2) return role.name;
  return t('CUSTOM_ROLE.DUPLICATE_LABEL', { name: role.name, id: role.id });
};

export const getCustomRoleLabel = (customRoles, roleId, t) => {
  const role = customRoles.find(customRole => customRole.id === roleId);
  if (!role) return '';

  return roleLabel(role, countLabels(customRoles), t);
};

export const getAgentRoleOptions = (customRoles, t) => {
  const labelCounts = countLabels(customRoles);

  const builtInRoles = [
    {
      id: 'administrator',
      name: 'administrator',
      label: t('AGENT_MGMT.AGENT_TYPES.ADMINISTRATOR'),
    },
    {
      id: 'agent',
      name: 'agent',
      label: t('AGENT_MGMT.AGENT_TYPES.AGENT'),
    },
  ];

  const customRoleOptions = customRoles.map(role => ({
    id: role.id,
    name: `custom_${role.id}`,
    label: roleLabel(role, labelCounts, t),
  }));

  return [...builtInRoles, ...customRoleOptions];
};
