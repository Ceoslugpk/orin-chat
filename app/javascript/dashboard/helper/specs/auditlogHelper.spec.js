import enAuditLogs from '../../i18n/locale/en/auditLogs.json';
import enCustomRole from '../../i18n/locale/en/customRole.json';
import {
  extractChangedAccountUserValues,
  generateTranslationPayload,
  generateLogActionKey,
  auditLogFiltersFromQuery,
  buildAuditLogRouteQuery,
} from '../auditlogHelper'; // import the functions

const flatten = (source, prefix = '') =>
  Object.entries(source).reduce((flat, [key, value]) => {
    const path = prefix ? `${prefix}.${key}` : key;
    if (value && typeof value === 'object') {
      return { ...flat, ...flatten(value, path) };
    }
    return { ...flat, [path]: value };
  }, {});

const messages = {
  ...flatten(enAuditLogs),
  ...flatten(enCustomRole),
};

const interpolate = (template, params = {}) =>
  Object.entries(params).reduce(
    (text, [key, value]) => text.replaceAll(`{${key}}`, String(value)),
    template
  );

const t = (key, params) =>
  key in messages ? interpolate(messages[key], params) : key;

describe('Helper functions', () => {
  const agentList = [
    { id: 1, name: 'Agent 1' },
    { id: 2, name: 'Agent 2' },
    { id: 3, name: 'Agent 3' },
  ];

  const customRoleList = [
    { id: 91, name: 'Reporting', permissions: ['report_manage'] },
    { id: 92, name: 'Reporting', permissions: ['conversation_manage'] },
  ];

  describe('extractChangedAccountUserValues', () => {
    it('should correctly extract values when role is changed', () => {
      const changes = {
        role: [0, 1],
      };
      const { changes: extractedChanges, values } =
        extractChangedAccountUserValues(changes);
      expect(extractedChanges).toEqual(['role']);
      expect(values).toEqual(['administrator']);
    });

    it('should correctly extract values when availability is changed', () => {
      const changes = {
        availability: [0, 2],
      };
      const { changes: extractedChanges, values } =
        extractChangedAccountUserValues(changes);
      expect(extractedChanges).toEqual(['availability']);
      expect(values).toEqual(['busy']);
    });

    it('should correctly extract values when both are changed', () => {
      const changes = {
        role: [1, 0],
        availability: [1, 2],
      };
      const { changes: extractedChanges, values } =
        extractChangedAccountUserValues(changes);
      expect(extractedChanges).toEqual(['role', 'availability']);
      expect(values).toEqual(['agent', 'busy']);
    });

    it('should describe auto_offline changes', () => {
      const changes = {
        auto_offline: [true, false],
      };
      const { changes: extractedChanges, values } =
        extractChangedAccountUserValues(changes, [], t);
      expect(extractedChanges).toEqual(['auto_offline']);
      expect(values).toEqual(['auto offline disabled']);
    });

    it('uses a unique built-in role id when the definition is unknown', () => {
      const changes = {
        custom_role_id: [null, 93],
      };
      const { changes: extractedChanges, values } =
        extractChangedAccountUserValues(changes, customRoleList, t);
      expect(extractedChanges).toEqual(['custom_role_id']);
      expect(values).toEqual(['#93']);
    });

    it('labels a duplicate definition by definition ID', () => {
      const changes = {
        custom_role_id: [91, 92],
      };
      const { values } = extractChangedAccountUserValues(
        changes,
        customRoleList,
        t
      );
      expect(values).toEqual(['Reporting (#92)']);
    });

    it('describes a removed definition reference', () => {
      const changes = {
        custom_role_id: [91, null],
      };
      const { values } = extractChangedAccountUserValues(
        changes,
        customRoleList,
        t
      );
      expect(values).toEqual(['no custom role']);
    });

    it('describes a newly assigned custom role', () => {
      const changes = {
        custom_role_id: [null, 91],
      };
      const { changes: extractedChanges, values } =
        extractChangedAccountUserValues(changes, customRoleList, t);
      expect(extractedChanges).toEqual(['custom_role_id']);
      expect(values).toEqual(['Reporting (#91)']);
    });
  });

  describe('generateTranslationPayload', () => {
    it('should handle AccountUser create', () => {
      const auditLogItem = {
        auditable_type: 'AccountUser',
        action: 'create',
        user_id: 1,
        auditable_id: 123,
        audited_changes: {
          user_id: 2,
          role: 1,
        },
      };

      const payload = generateTranslationPayload(auditLogItem, agentList);
      expect(payload).toEqual({
        agentName: 'Agent 1',
        id: 123,
        invitee: 'Agent 2',
        role: 'administrator',
      });
    });

    it('should handle AccountUser update', () => {
      const auditLogItem = {
        auditable_type: 'AccountUser',
        action: 'update',
        user_id: 1,
        auditable_id: 123,
        audited_changes: {
          user_id: 2,
          role: [1, 0],
          availability: [0, 2],
        },
        auditable: {
          user_id: 3,
        },
      };

      const payload = generateTranslationPayload(
        auditLogItem,
        agentList,
        customRoleList,
        t
      );
      expect(payload).toEqual({
        agentName: 'Agent 1',
        id: 123,
        user: 'Agent 3',
        attributes: ['role', 'availability'],
        values: ['agent', 'busy'],
      });
    });

    it('identifies a removed account agent from the saved audit changes', () => {
      const payload = generateTranslationPayload(
        {
          auditable_type: 'AccountUser',
          action: 'destroy',
          auditable_id: 123,
          user_id: 1,
          audited_changes: { user_id: 2 },
          auditable: null,
        },
        agentList
      );

      expect(payload).toEqual({
        agentName: 'Agent 1',
        id: 123,
        user: 'Agent 2',
      });
    });

    it('should handle InboxMember or TeamMember', () => {
      const auditLogItemInboxMember = {
        auditable_type: 'InboxMember',
        action: 'create',
        audited_changes: {
          user_id: 2,
        },
        user_id: 1,
        auditable_id: 789,
      };

      const payloadInboxMember = generateTranslationPayload(
        auditLogItemInboxMember,
        agentList
      );
      expect(payloadInboxMember).toEqual({
        agentName: 'Agent 1',
        id: 789,
        user: 'Agent 2',
      });

      const auditLogItemTeamMember = {
        auditable_type: 'TeamMember',
        action: 'create',
        audited_changes: {
          user_id: 3,
        },
        user_id: 1,
        auditable_id: 789,
      };

      const payloadTeamMember = generateTranslationPayload(
        auditLogItemTeamMember,
        agentList
      );
      expect(payloadTeamMember).toEqual({
        agentName: 'Agent 1',
        id: 789,
        user: 'Agent 3',
      });
    });

    it('should handle Message destroy with the conversation display id', () => {
      const auditLogItem = {
        auditable_type: 'Message',
        action: 'destroy',
        user_id: 1,
        auditable_id: 55123,
        audited_changes: {
          display_id: 1234,
        },
      };

      const payload = generateTranslationPayload(auditLogItem, agentList);
      expect(payload).toEqual({
        agentName: 'Agent 1',
        id: 55123,
        conversationId: 1234,
      });
    });

    it('should handle generic case like Team create', () => {
      const auditLogItem = {
        auditable_type: 'Team',
        action: 'create',
        user_id: 1,
        auditable_id: 456,
      };

      const payload = generateTranslationPayload(auditLogItem, agentList);
      expect(payload).toEqual({
        agentName: 'Agent 1',
        id: 456,
      });
    });
  });

  describe('generateLogActionKey', () => {
    it('should generate correct action key when user updates self', () => {
      const auditLogItem = {
        auditable_type: 'AccountUser',
        action: 'update',
        user_id: 1,
        auditable: {
          user_id: 1,
        },
      };

      const logActionKey = generateLogActionKey(auditLogItem);
      expect(logActionKey).toEqual('AUDIT_LOGS.ACCOUNT_USER.EDIT.SELF');
    });

    it('should generate correct action key when user updates other agent', () => {
      const auditLogItem = {
        auditable_type: 'AccountUser',
        action: 'update',
        user_id: 1,
        auditable: {
          user_id: 2,
        },
      };

      const logActionKey = generateLogActionKey(auditLogItem);
      expect(logActionKey).toEqual('AUDIT_LOGS.ACCOUNT_USER.EDIT.OTHER');
    });

    it('should generate correct action key when a message is deleted', () => {
      const auditLogItem = {
        auditable_type: 'Message',
        action: 'destroy',
        user_id: 1,
        auditable_id: 42,
      };

      const logActionKey = generateLogActionKey(auditLogItem);
      expect(logActionKey).toEqual('AUDIT_LOGS.MESSAGE.DELETE');
    });

    it('returns a translated action key when removing an account agent', () => {
      expect(
        generateLogActionKey({
          auditable_type: 'AccountUser',
          action: 'destroy',
        })
      ).toBe('AUDIT_LOGS.ACCOUNT_USER.REMOVE');
    });

    it.each([
      ['create', 'ADD'],
      ['update', 'EDIT'],
      ['destroy', 'DELETE'],
    ])('renders a custom-role %s audit event', (action, key) => {
      expect(
        generateLogActionKey({ auditable_type: 'CustomRole', action })
      ).toBe(`AUDIT_LOGS.CUSTOM_ROLE.${key}`);
    });

    it('should generate correct action key when updating a deleted user', () => {
      const auditLogItem = {
        auditable_type: 'AccountUser',
        action: 'update',
        user_id: 1,
        auditable: null,
      };

      const logActionKey = generateLogActionKey(auditLogItem);
      expect(logActionKey).toEqual('AUDIT_LOGS.ACCOUNT_USER.EDIT.DELETED');
    });
  });

  describe('#auditLogFiltersFromQuery', () => {
    it('maps route query params to API filters', () => {
      expect(
        auditLogFiltersFromQuery({
          page: '2',
          q: 'jane',
          type: 'Inbox',
          sort: 'asc',
          since: '100',
          until: '200',
        })
      ).toEqual({
        page: 2,
        q: 'jane',
        types: ['Inbox'],
        sort: 'asc',
        since: 100,
        until: 200,
      });
    });

    it('supports filtering role-definition changes', () => {
      expect(auditLogFiltersFromQuery({ type: 'CustomRole' })).toEqual({
        page: 1,
        types: ['CustomRole'],
      });
    });

    it('defaults to page 1 and drops unknown values', () => {
      expect(
        auditLogFiltersFromQuery({ sort: 'sideways', range: 'last7days' })
      ).toEqual({ page: 1 });
    });

    it('ignores a half open date window', () => {
      expect(auditLogFiltersFromQuery({ since: '100' })).toEqual({ page: 1 });
    });
  });

  describe('#buildAuditLogRouteQuery', () => {
    it('drops blank values', () => {
      expect(
        buildAuditLogRouteQuery({
          q: '',
          type: 'Inbox',
          range: 'last7days',
          page: undefined,
        })
      ).toEqual({ type: 'Inbox', range: 'last7days' });
    });
  });
});
