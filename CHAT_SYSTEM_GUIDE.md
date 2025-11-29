# 💬 CHAT SYSTEM - Complete Guide

## 🏗️ How the Chat System Works

Your app has **TWO types of chats**:

### 1. **Direct Chat** (1-on-1 between two users)
- Private conversation between you and another user
- Created automatically when you start chatting with someone

### 2. **Group Chat** (Multiple users)
- One person creates a group with a name
- Multiple users can join
- Everyone in the group can see all messages

---

## 📱 How Users Start a Chat

### **Direct Chat Flow:**

```
User Flow:
1. Home Screen → Click "Messages" or "Chats"
2. Chat List Screen (empty at first)
3. Click the "+" button (FloatingActionButton)
4. Opens "New Chat" screen
5. Search for a user by name/email
6. Click on a user
7. Opens chat room with that user
8. Start sending messages!
```

**Behind the Scenes:**
```dart
// When user clicks on another user in search results:
1. new_chat_screen.dart calls: _startChat(userId)
2. ChatProvider.startDirectChat(userId) 
3. ChatService.getOrCreateDirectChat(userId)
   - Checks if chat already exists between you two
   - If exists: Returns existing chat room
   - If not: Creates new chat room + adds both users as participants
4. Opens chat_room_screen.dart
5. User can send messages via chat_provider → chat_service
```

---

## 🗄️ Database Structure

### Tables Used:

1. **chat_rooms** - The chat container
   ```sql
   - id (uuid)
   - name (text) - only for group chats
   - is_group (boolean) - true for groups, false for direct
   - created_by (uuid) - user who created it
   - created_at (timestamp)
   ```

2. **chat_participants** - Who's in the chat
   ```sql
   - id (uuid)
   - room_id (uuid) - references chat_rooms
   - user_id (uuid) - references profiles
   - joined_at (timestamp)
   ```

3. **messages** - The actual messages
   ```sql
   - id (uuid)
   - room_id (uuid) - which chat
   - sender_id (uuid) - who sent it
   - content (text) - the message
   - message_type (text) - 'text', 'image', 'file', 'video'
   - file_url (text) - if it's a file/image
   - is_read (boolean)
   - created_at (timestamp)
   ```

---

## 🔄 Real-time Updates

**How messages appear instantly:**

```dart
// In chat_room_screen.dart:
1. User opens a chat room
2. Subscribes to messages via: chatService.subscribeToMessages(roomId)
3. Uses Supabase Realtime to listen for new messages
4. When anyone sends a message:
   - Supabase broadcasts to all connected users in that room
   - ChatProvider receives the message
   - UI updates automatically (no refresh needed!)
```

---

## 💻 Code Flow Examples

### Example 1: Starting a Direct Chat

```dart
// User searches for "John" and clicks on him
// john's userId = "abc123"

// 1. new_chat_screen.dart
_startChat("abc123") {
  chatProvider.startDirectChat("abc123")
}

// 2. chat_provider.dart
startDirectChat("abc123") {
  room = chatService.getOrCreateDirectChat("abc123")
  // Returns: ChatRoomModel(id: "xyz", isGroup: false, participants: [you, john])
}

// 3. chat_service.dart checks:
// - Is there already a chat between me and John?
// - YES: Return existing chat
// - NO: Create new chat_room + add both as participants

// 4. Navigate to chat_room_screen
// 5. Load messages for that room_id
// 6. Subscribe to real-time updates
```

### Example 2: Sending a Message

```dart
// User types "Hello!" and hits send

// 1. chat_room_screen.dart
_sendMessage("Hello!") {
  chatProvider.sendMessage(content: "Hello!", messageType: "text")
}

// 2. chat_provider.dart
sendMessage(content, messageType) {
  message = chatService.sendMessage(
    roomId: currentRoom.id,
    content: "Hello!",
    messageType: "text"
  )
}

// 3. chat_service.dart
// - Inserts into messages table with your sender_id
// - Returns the saved message
// - Real-time broadcasts to all room participants
// - Other user's screen updates automatically!
```

### Example 3: Creating a Group Chat

```dart
// User creates "Study Group" with 3 friends
// friendIds = ["user1", "user2", "user3"]

// chat_provider.dart
createGroupChat(
  name: "Study Group",
  memberIds: ["user1", "user2", "user3"]
)

// chat_service.dart
createGroupChat() {
  // 1. Create chat_room with is_group=true, name="Study Group"
  // 2. Add you + all 3 friends to chat_participants
  // 3. Return the room
  // 4. Anyone in the group can now send messages!
}
```

---

## 🚨 IMPORTANT: Before Chat Works

### ⚠️ You MUST run this SQL first:

```bash
# In Supabase Dashboard -> SQL Editor
# Run: FIX_CHAT_RECURSION.sql
```

**Why?** 
- Your current RLS policies have circular references
- Chat will fail with "infinite recursion" error
- This SQL fixes the policies

---

## 🧪 Testing the Chat System

### Test Direct Chat:

1. **Create 2 test accounts:**
   - Account A: user1@test.com
   - Account B: user2@test.com

2. **Login as user1@test.com:**
   - Go to Messages
   - Click "+" button
   - Search for "user2"
   - Click on user2
   - Send message: "Hey user2!"

3. **Login as user2@test.com** (different device/browser):
   - Go to Messages
   - Should see chat with user1
   - Open it
   - Should see "Hey user2!" message
   - Reply: "Hi user1!"

4. **Check user1's screen:**
   - Message should appear INSTANTLY (real-time!)

---

## 📸 Sending Files/Images in Chat

Your chat supports different message types:

```dart
// Text message (default)
sendMessage(content: "Hello", messageType: "text")

// Image
sendMessage(
  content: "Check this out!",
  messageType: "image",
  fileUrl: "https://your-storage.com/image.jpg"
)

// File
sendMessage(
  content: "Document attached",
  messageType: "file", 
  fileUrl: "https://your-storage.com/doc.pdf"
)

// Video
sendMessage(
  content: "Video message",
  messageType: "video",
  fileUrl: "https://your-storage.com/video.mp4"
)
```

**To send an image:**
1. Use `StorageService` to upload image to `chat-files` bucket
2. Get the public URL
3. Send message with that URL + messageType: "image"

---

## 🎯 Current Implementation Status

### ✅ What's Implemented:

- Direct chat between 2 users
- Group chat creation
- Real-time message updates
- Message sending (text + file URLs)
- Chat room list
- User search for new chats
- Unread message count
- Message read status

### 🚧 What You Might Want to Add:

- File upload UI in chat (currently you have the service, just need UI)
- Voice messages
- Message reactions/emojis
- Delete messages
- Edit messages
- Typing indicators
- Online/offline status
- Push notifications for new messages

---

## 🔧 How to Access Chat in Your App

### From Home Screen:

```dart
// In home_screen.dart or dashboard_screen.dart
// Add a button/card that navigates to:
Navigator.pushNamed(context, AppConstants.chatListRoute);
// This opens: lib/screens/chat/chat_list_screen.dart
```

### Routes Already Configured:

```dart
// In app_routes.dart:
'/chat/list'     -> ChatListScreen     // Shows all your chats
'/chat/new'      -> NewChatScreen      // Search users to chat with
'/chat/room'     -> ChatRoomScreen     // The actual chat window
'/chat/create'   -> CreateGroupScreen  // Create a group (if you want to add this)
```

---

## 🐛 Troubleshooting

### "Infinite recursion" error:
✅ **Fix:** Run `FIX_CHAT_RECURSION.sql` in Supabase

### Messages not sending:
- Check if you ran the SQL fix above
- Check Supabase logs for RLS policy errors
- Verify user is authenticated

### Real-time not working:
- Check if Realtime is enabled in Supabase Dashboard
- Settings -> API -> Realtime -> Should be ON
- Check browser console for connection errors

### Can't find users to chat with:
- Make sure multiple users are registered
- Search functionality looks in `profiles` table
- Check `user_service.dart` searchUsers() method

---

## 📝 Summary

**Direct Chat:**
- User searches → clicks user → chat opens → send messages
- Automatically creates chat room if doesn't exist

**Group Chat:**
- Create group with name + add members
- Everyone can see all messages
- Anyone can invite more members (if you add that feature)

**Real-time:**
- Uses Supabase Realtime
- Messages appear instantly
- No need to refresh

**Next Steps:**
1. Run `FIX_CHAT_RECURSION.sql` 
2. Hot restart app
3. Create 2 test accounts
4. Test chatting between them!

---

🎉 **Your chat system is feature-complete and ready to use!**
