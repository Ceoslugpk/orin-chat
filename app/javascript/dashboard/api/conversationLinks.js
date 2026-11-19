/* global axios */

import ApiClient from './ApiClient';

class ConversationLinksAPI extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true });
  }

  get(conversationId) {
    return axios.get(`${this.url}/${conversationId}/links`);
  }

  create(conversationId, linkedConversationId) {
    return axios.post(`${this.url}/${conversationId}/links`, {
      linked_conversation_id: linkedConversationId,
    });
  }

  delete(conversationId, linkId) {
    return axios.delete(`${this.url}/${conversationId}/links/${linkId}`);
  }

  merge(conversationId, targetConversationId) {
    return axios.post(`${this.url}/${conversationId}/merge`, {
      target_conversation_id: targetConversationId,
    });
  }
}

export default new ConversationLinksAPI();
