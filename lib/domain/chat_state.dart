/// Conversation flow states for a Jarvis session (ported from Python).
enum ChatState {
  notInitialized,
  jarvisWelcomeMessage,
  startingChat,
  initialized,
}

/// Behavior when the user is not identified.
///
/// Local MVP always uses a configured profile (`validUser: true`). Hostile /
/// ID-protocol branches remain for parity with Python and possible use in #6.
enum IdentificationFailedProtocol {
  automaticResponse,
  hostileResponses,
}

/// Compute the next state with no side effects.
ChatState computeNextChatState(
  ChatState current, {
  required bool validUser,
  required bool wasPreviouslyInvalid,
  IdentificationFailedProtocol identificationProtocol =
      IdentificationFailedProtocol.automaticResponse,
}) {
  if (current == ChatState.notInitialized) {
    if (validUser) return ChatState.jarvisWelcomeMessage;
    if (identificationProtocol == IdentificationFailedProtocol.hostileResponses) {
      return ChatState.startingChat;
    }
    return ChatState.notInitialized;
  }

  if (current == ChatState.jarvisWelcomeMessage) {
    return ChatState.startingChat;
  }

  if (current == ChatState.startingChat) {
    return ChatState.initialized;
  }

  if (current == ChatState.initialized) {
    if (wasPreviouslyInvalid && validUser) {
      return ChatState.jarvisWelcomeMessage;
    }
    return ChatState.initialized;
  }

  return current;
}

/// Whether to clear the agent thread after identifying during active chat.
bool shouldClearAgentThreadOnIdentification(
  ChatState current, {
  required bool wasPreviouslyInvalid,
  required bool validUser,
}) {
  return current == ChatState.initialized &&
      wasPreviouslyInvalid &&
      validUser;
}
