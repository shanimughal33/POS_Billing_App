# Firebase Cloud Messaging Setup Guide

## Step 1: Firebase Console Setup

### 1.1 Create/Configure Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your existing project or create a new one
3. Ensure your app is registered in the project

### 1.2 Enable Cloud Messaging
1. In Firebase Console, go to **Project Settings**
2. Click on the **Cloud Messaging** tab
3. Enable **Cloud Messaging API** if not already enabled

## Step 2: Android Configuration

### 2.1 Download google-services.json
1. In Firebase Console, go to **Project Settings**
2. Under **Your apps**, select your Android app
3. Download the `google-services.json` file
4. Place it in `android/app/` directory of your Flutter project

### 2.2 Update Android Manifest
The following permissions should already be in your `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

### 2.3 Update build.gradle
Ensure your `android/app/build.gradle` has:

```gradle
dependencies {
    implementation platform('com.google.firebase:firebase-bom:32.7.0')
    implementation 'com.google.firebase:firebase-messaging'
    implementation 'com.google.firebase:firebase-analytics'
}
```

## Step 3: iOS Configuration (if applicable)

### 3.1 Download GoogleService-Info.plist
1. In Firebase Console, go to **Project Settings**
2. Under **Your apps**, select your iOS app
3. Download the `GoogleService-Info.plist` file
4. Place it in `ios/Runner/` directory

### 3.2 Update iOS Configuration
1. Open `ios/Runner/Info.plist`
2. Add the following:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

## Step 4: Testing Notifications

### 4.1 Send Test Notification
1. In Firebase Console, go to **Cloud Messaging**
2. Click **Send your first message**
3. Fill in the notification details:
   - **Notification title**: "Test Notification"
   - **Notification text**: "This is a test notification"
4. Under **Target**, select **Single device** and paste your FCM token
5. Click **Send**

### 4.2 Get FCM Token
The app automatically logs the FCM token. Check your debug console for:
```
NotificationService: FCM Token: [your-token-here]
```

## Step 5: Topic-based Notifications

### 5.1 Subscribe to Topics
Your app automatically subscribes to topics based on user actions:
- `sales_${userId}` - Sales notifications
- `inventory_${userId}` - Inventory notifications
- `expense_${userId}` - Expense notifications
- `reminder_${userId}` - Reminder notifications

### 5.2 Send Topic Notifications
1. In Firebase Console, go to **Cloud Messaging**
2. Click **Send your first message**
3. Under **Target**, select **Topic**
4. Choose a topic (e.g., `sales_all` for all sales notifications)
5. Send the message

## Step 6: Server-side Integration (Optional)

### 6.1 Using Firebase Admin SDK
```javascript
const admin = require('firebase-admin');
const serviceAccount = require('./path/to/serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

// Send to specific user
const message = {
  notification: {
    title: 'New Sale!',
    body: 'You made a sale of Rs 2,500'
  },
  data: {
    category: 'sales',
    action: 'view_sale',
    sale_id: 'sale_123'
  },
  token: 'user-fcm-token'
};

admin.messaging().send(message);
```

### 6.2 Using cURL
```bash
curl -X POST -H "Authorization: key=YOUR-SERVER-KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "to": "USER-FCM-TOKEN",
       "notification": {
         "title": "New Sale!",
         "body": "You made a sale of Rs 2,500"
       },
       "data": {
         "category": "sales",
         "action": "view_sale",
         "sale_id": "sale_123"
       }
     }' \
     https://fcm.googleapis.com/fcm/send
```

## Step 7: Notification Categories

### 7.1 Sales Notifications
- **Trigger**: New sale completed
- **Data**: `{category: 'sales', action: 'view_sale', sale_id: 'xxx'}`
- **Navigation**: Sales screen

### 7.2 Inventory Notifications
- **Trigger**: Low stock, new item added
- **Data**: `{category: 'inventory', action: 'view_item', item_id: 'xxx'}`
- **Navigation**: Inventory screen

### 7.3 Expense Notifications
- **Trigger**: New expense added
- **Data**: `{category: 'expense', action: 'view_expense', expense_id: 'xxx'}`
- **Navigation**: Expense screen

### 7.4 Reminder Notifications
- **Trigger**: Daily reminders, scheduled tasks
- **Data**: `{category: 'reminder', action: 'view_report', report_type: 'daily'}`
- **Navigation**: Reports screen

## Step 8: Troubleshooting

### 8.1 Common Issues
1. **Token not generated**: Check Firebase configuration files
2. **Notifications not received**: Verify permissions and token
3. **Background notifications**: Ensure proper manifest configuration

### 8.2 Debug Commands
```bash
# Check if FCM is working
flutter logs | grep "NotificationService"

# Verify token generation
flutter logs | grep "FCM Token"
```

### 8.3 Testing Checklist
- [ ] FCM token is generated and logged
- [ ] Test notification received in foreground
- [ ] Test notification received in background
- [ ] Notification tap navigation works
- [ ] Local notifications work
- [ ] Topic subscriptions work

## Step 9: Production Deployment

### 9.1 Security Rules
1. Set up proper Firebase Security Rules
2. Implement user authentication
3. Validate notification payloads

### 9.2 Monitoring
1. Use Firebase Analytics to track notification engagement
2. Monitor notification delivery rates
3. Set up error alerts for failed notifications

### 9.3 Best Practices
1. Send notifications at appropriate times
2. Use rich notifications with images when relevant
3. Implement notification preferences
4. Handle notification actions properly
5. Test on multiple devices and OS versions

## Step 10: Advanced Features

### 10.1 Rich Notifications
```javascript
const message = {
  notification: {
    title: 'New Sale!',
    body: 'You made a sale of Rs 2,500',
    image: 'https://example.com/sale-image.jpg'
  },
  android: {
    notification: {
      image: 'https://example.com/sale-image.jpg',
      color: '#1976D2',
      sound: 'default'
    }
  },
  apns: {
    payload: {
      aps: {
        'mutable-content': 1,
        sound: 'default'
      }
    },
    fcm_options: {
      image: 'https://example.com/sale-image.jpg'
    }
  }
};
```

### 10.2 Scheduled Notifications
```javascript
const message = {
  notification: {
    title: 'Daily Report',
    body: 'Your daily sales report is ready'
  },
  android: {
    ttl: 86400000, // 24 hours
    priority: 'normal'
  },
  apns: {
    headers: {
      'apns-expiration': '86400'
    }
  }
};
```

This setup guide covers all aspects of implementing Firebase Cloud Messaging in your Flutter billing app. Follow each step carefully and test thoroughly before deploying to production. 