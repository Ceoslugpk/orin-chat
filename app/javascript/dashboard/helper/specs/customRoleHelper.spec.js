import { getAgentRoleOptions, getCustomRoleLabel } from '../customRoleHelper';

const t = (key, params) =>
  params ? `${key}:${params.name}:${params.id}` : key;

const uniqueRoles = [
  { id: 91, name: 'Reporting', permissions: ['report_manage'] },
  { id: 92, name: 'Contacts', permissions: ['contact_manage'] },
];

const duplicateRoles = [
  { id: 93, name: 'Support', permissions: ['conversation_manage'] },
  { id: 94, name: 'Support', permissions: ['contact_manage'] },
];

describe('customRoleHelper', () => {
  describe('getAgentRoleOptions', () => {
    it('keeps unique custom role labels unchanged', () => {
      const options = getAgentRoleOptions(uniqueRoles, t);

      expect(options.map(option => option.label)).toEqual([
        'AGENT_MGMT.AGENT_TYPES.ADMINISTRATOR',
        'AGENT_MGMT.AGENT_TYPES.AGENT',
        'Reporting',
        'Contacts',
      ]);
    });

    it('disambiguates duplicate custom role labels with the definition id', () => {
      const customRoleOptions = getAgentRoleOptions(duplicateRoles, t).slice(2);

      expect(customRoleOptions.map(option => option.label)).toEqual([
        'CUSTOM_ROLE.DUPLICATE_LABEL:Support:93',
        'CUSTOM_ROLE.DUPLICATE_LABEL:Support:94',
      ]);
      expect(customRoleOptions.map(option => option.name)).toEqual([
        'custom_93',
        'custom_94',
      ]);
    });
  });

  describe('getCustomRoleLabel', () => {
    it('returns the unchanged label for a unique definition', () => {
      expect(getCustomRoleLabel(uniqueRoles, 91, t)).toBe('Reporting');
    });

    it('returns a disambiguated label for a duplicate definition', () => {
      expect(getCustomRoleLabel(duplicateRoles, 94, t)).toBe(
        'CUSTOM_ROLE.DUPLICATE_LABEL:Support:94'
      );
    });

    it('returns an empty label for a missing definition', () => {
      expect(getCustomRoleLabel(uniqueRoles, 999, t)).toBe('');
    });
  });
});
