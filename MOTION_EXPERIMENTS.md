# Telegram iOS – motion design experiments (full list)

Built into the open-source Telegram iOS app (`~/Desktop/Telegram-iOS`). Real code, mostly Core Animation.
All of it is skipped under **Reduce Motion** (the press/hold feedback stays functional). Nothing runs per
frame except the two scroll effects.

## Profile
1. Aurora backdrop – soft colour blobs behind the avatar (cover colours, or thenow,me accent) · `PeerInfoAuroraBackdrop.swift`
2. Dancing bubbles – six glass emoji bubbles orbit the avatar + breathing halo · `PeerInfoFloatingBubbles.swift`
3. Avatar entrance spring · `PeerInfoScreen.swift`
4. Action buttons (call/mute/search/more): springy press, and pop in one after another on open · `PeerInfoHeaderButtonNode.swift`, `PeerInfoScreen.swift`
5. Info sections rise in on open · `PeerInfoScreen.swift`
6. Hold the picture: lifts + glowing ring (own Settings avatar uses its own hold recognizer) · `PeerInfoAvatarTransformContainerNode.swift`
7. Content-tab switching: leaving pane recedes/fades, arriving pane grows in · `PeerInfoPaneContainerNode.swift`

## Settings
8. Sections rise in one after another each time the tab is shown · `PeerInfoScreen.swift`

## Chat
9. Incoming message pop-in · `ChatMessageBubbleItemNode.swift`
10. Send (text): button pop, ripple, dots, confetti, flying paper plane · `SendFlourish.swift`, `ChatTextInputPanelNode.swift`
11. Attachment button spins a full turn on tap · `ChatTextInputPanelNode.swift`
12. Reaction burst – sparkles from a tapped reaction · `ReactionBurstView.swift`, `ReactionContextNode.swift`
13. Swipe-to-reply arrow pops with overshoot · `ChatMessageSwipeToReplyNode.swift`
14. Sent/read ticks pop with overshoot · `ChatMessageDateAndStatusNode.swift`
15. "Scroll to bottom" button bounces in · `ChatHistoryNavigationButtons.swift`

## Chat list
16. Scroll jelly – avatars trail/shrink, text leans the other way · `ChatListItem.swift`
17. Rows rise in at launch (main list) / slide in (Archive, during the push) · `ChatListController.swift`

## Bottom tab bar
18. Liquid pill stretches between tabs; gradient fill + hairline border · `TabBarNode.swift`
19. New tab slides in from the direction you moved · `TabBarController.swift`