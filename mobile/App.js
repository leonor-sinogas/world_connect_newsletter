import { useEffect, useMemo, useState } from "react";
import {
  ActivityIndicator,
  Image,
  Pressable,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";
import { StatusBar } from "expo-status-bar";
import { useFonts } from "expo-font";
import * as ImagePicker from "expo-image-picker";
import { Ionicons } from "@expo/vector-icons";

const API_BASE_URL = "http://localhost:8000";

const tabs = [
  { key: "home", label: "Home", icon: "home" },
  { key: "friends", label: "Friends", icon: "people" },
  { key: "newsletters", label: "Newsletters", icon: "newspaper" },
  { key: "profile", label: "Profile", icon: "person" },
];

const categoryOptions = ["family", "friends", "travel", "custom"];

async function api(path, options = {}) {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      ...(options.headers || {}),
    },
  });
  const data = response.status === 204 ? null : await response.json();
  if (!response.ok) {
    throw new Error(data?.detail || "Something went wrong");
  }
  return data;
}

function formatDate(value, timeZone = "UTC") {
  if (!value) {
    return "";
  }
  return new Intl.DateTimeFormat(undefined, {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone,
  }).format(new Date(value));
}

function SectionTitle({ children }) {
  return <Text style={styles.sectionTitle}>{children}</Text>;
}

function EmptyState({ children }) {
  return <Text style={styles.empty}>{children}</Text>;
}

export default function App() {
  const [iconsLoaded] = useFonts(Ionicons.font);
  const [user, setUser] = useState(null);
  const [authMode, setAuthMode] = useState("login");
  const [authUsername, setAuthUsername] = useState("");
  const [authEmail, setAuthEmail] = useState("");
  const [authPassword, setAuthPassword] = useState("");
  const [resetCode, setResetCode] = useState("");
  const [resetDevCode, setResetDevCode] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [activeTab, setActiveTab] = useState("home");
  const [feed, setFeed] = useState([]);
  const [newsletters, setNewsletters] = useState([]);
  const [friendsData, setFriendsData] = useState({ friends: [], incoming: [], outgoing: [], prospective: [] });
  const [loading, setLoading] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState("");
  const [showComposer, setShowComposer] = useState(false);
  const [newNewsletterTitle, setNewNewsletterTitle] = useState("");
  const [newNewsletterDescription, setNewNewsletterDescription] = useState("");
  const [newNewsletterVisibility, setNewNewsletterVisibility] = useState("public");
  const [newNewsletterCategory, setNewNewsletterCategory] = useState("friends");
  const [customNewsletterCategory, setCustomNewsletterCategory] = useState("");
  const [issueNewsletterId, setIssueNewsletterId] = useState("");
  const [issueTitle, setIssueTitle] = useState("");
  const [issueBody, setIssueBody] = useState("");
  const [issuePhotoUrl, setIssuePhotoUrl] = useState("");
  const [replyTextByIssue, setReplyTextByIssue] = useState({});
  const [profilePhotoUrl, setProfilePhotoUrl] = useState("");
  const [timeZone, setTimeZone] = useState("GMT");

  const subscribedNewsletters = useMemo(
    () => newsletters.filter((newsletter) => newsletter.is_subscribed),
    [newsletters],
  );

  async function refreshAll(currentUser = user) {
    if (!currentUser) {
      return;
    }
    setError("");
    setLoading(true);
    try {
      const [feedData, newslettersData, friendsPayload] = await Promise.all([
        api(`/users/${currentUser.id}/feed`),
        api(`/newsletters?user_id=${currentUser.id}`),
        api(`/users/${currentUser.id}/friends`),
      ]);
      setFeed(feedData);
      setNewsletters(newslettersData);
      setFriendsData(friendsPayload);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  async function submitAuth() {
    if (!authUsername.trim() || !authPassword.trim() || (authMode === "signup" && !authEmail.trim())) {
      setError(authMode === "signup" ? "Username, email, and password are required" : "Username and password are required");
      return;
    }
    setError("");
    setLoading(true);
    try {
      const nextUser = await api(authMode === "login" ? "/auth/login" : "/auth/signup", {
        method: "POST",
        body: JSON.stringify({
          username: authUsername.trim(),
          email: authEmail.trim(),
          password: authPassword,
          time_zone: authMode === "signup" ? "GMT" : timeZone,
        }),
      });
      setUser(nextUser);
      setProfilePhotoUrl(nextUser.profile_photo_url);
      setTimeZone(nextUser.time_zone || timeZone);
      setAuthPassword("");
      await refreshAll(nextUser);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  async function requestPasswordReset() {
    if (!authEmail.trim()) {
      setError("Enter the email for your account");
      return;
    }
    setError("");
    setLoading(true);
    try {
      const result = await api("/auth/recover-password", {
        method: "POST",
        body: JSON.stringify({ email: authEmail.trim() }),
      });
      setResetDevCode(result.dev_code || "");
      setAuthMode("reset-code");
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  async function verifyResetCode() {
    setError("");
    setLoading(true);
    try {
      await api("/auth/verify-reset-code", {
        method: "POST",
        body: JSON.stringify({ email: authEmail.trim(), code: resetCode.trim() }),
      });
      setAuthMode("reset-password");
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  async function resetPassword() {
    if (!newPassword.trim()) {
      setError("Enter a new password");
      return;
    }
    setError("");
    setLoading(true);
    try {
      await api("/auth/reset-password", {
        method: "POST",
        body: JSON.stringify({ email: authEmail.trim(), code: resetCode.trim(), password: newPassword }),
      });
      setAuthPassword("");
      setNewPassword("");
      setResetCode("");
      setResetDevCode("");
      setAuthMode("login");
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  async function uploadImage() {
    setError("");
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      quality: 0.85,
    });
    if (result.canceled || !result.assets?.length) {
      return "";
    }

    const asset = result.assets[0];
    const formData = new FormData();
    if (asset.file) {
      formData.append("file", asset.file);
    } else {
      formData.append("file", {
        uri: asset.uri,
        name: asset.fileName || "upload.jpg",
        type: asset.mimeType || "image/jpeg",
      });
    }

    setUploading(true);
    try {
      const response = await fetch(`${API_BASE_URL}/uploads`, {
        method: "POST",
        body: formData,
      });
      const data = await response.json();
      if (!response.ok) {
        throw new Error(data?.detail || "Could not upload image");
      }
      return data.url;
    } catch (err) {
      setError(err.message);
      return "";
    } finally {
      setUploading(false);
    }
  }

  async function chooseProfilePhoto() {
    const url = await uploadImage();
    if (url) {
      setProfilePhotoUrl(url);
    }
  }

  async function chooseIssuePhoto() {
    const url = await uploadImage();
    if (url) {
      setIssuePhotoUrl(url);
    }
  }

  async function createNewsletter() {
    if (!newNewsletterTitle.trim()) {
      setError("Newsletter title is required");
      return;
    }
    if (newNewsletterCategory === "custom" && !customNewsletterCategory.trim()) {
      setError("Write a custom category name");
      return;
    }
    setError("");
    try {
      await api("/newsletters", {
        method: "POST",
        body: JSON.stringify({
          owner_id: user.id,
          title: newNewsletterTitle.trim(),
          description: newNewsletterDescription.trim(),
          visibility: newNewsletterVisibility,
          category: newNewsletterCategory === "custom" ? customNewsletterCategory.trim() : newNewsletterCategory,
        }),
      });
      setNewNewsletterTitle("");
      setNewNewsletterDescription("");
      setNewNewsletterVisibility("public");
      setNewNewsletterCategory("friends");
      setCustomNewsletterCategory("");
      await refreshAll();
    } catch (err) {
      setError(err.message);
    }
  }

  async function toggleSubscription(newsletter) {
    setError("");
    try {
      await api(`/newsletters/${newsletter.id}/subscribe?user_id=${user.id}`, {
        method: newsletter.is_subscribed ? "DELETE" : "POST",
      });
      await refreshAll();
    } catch (err) {
      setError(err.message);
    }
  }

  async function inviteToNewsletter(newsletter, inviteeId) {
    setError("");
    try {
      await api(`/newsletters/${newsletter.id}/invitations`, {
        method: "POST",
        body: JSON.stringify({ inviter_id: user.id, invitee_id: inviteeId }),
      });
      await refreshAll();
    } catch (err) {
      setError(err.message);
    }
  }

  async function createIssue() {
    const targetId = Number(issueNewsletterId || subscribedNewsletters[0]?.id);
    if (!targetId || !issueTitle.trim() || !issueBody.trim()) {
      setError("Choose a newsletter, then add a title and text");
      return;
    }
    setError("");
    try {
      await api(`/newsletters/${targetId}/issues`, {
        method: "POST",
        body: JSON.stringify({
          author_id: user.id,
          title: issueTitle.trim(),
          body: issueBody.trim(),
          photo_url: issuePhotoUrl.trim(),
        }),
      });
      setIssueTitle("");
      setIssueBody("");
      setIssuePhotoUrl("");
      setIssueNewsletterId("");
      setShowComposer(false);
      await refreshAll();
    } catch (err) {
      setError(err.message);
    }
  }

  async function sendReply(issueId) {
    const body = replyTextByIssue[issueId]?.trim();
    if (!body) {
      return;
    }
    setError("");
    try {
      await api(`/issues/${issueId}/replies`, {
        method: "POST",
        body: JSON.stringify({ author_id: user.id, body }),
      });
      setReplyTextByIssue((current) => ({ ...current, [issueId]: "" }));
      await refreshAll();
    } catch (err) {
      setError(err.message);
    }
  }

  async function sendFriendRequest(addresseeId) {
    setError("");
    try {
      await api("/friend-requests", {
        method: "POST",
        body: JSON.stringify({ requester_id: user.id, addressee_id: addresseeId }),
      });
      await refreshAll();
    } catch (err) {
      setError(err.message);
    }
  }

  async function updateFriendRequest(requestId, nextStatus) {
    setError("");
    try {
      await api(`/friend-requests/${requestId}`, {
        method: "PATCH",
        body: JSON.stringify({ status: nextStatus }),
      });
      await refreshAll();
    } catch (err) {
      setError(err.message);
    }
  }

  async function saveProfile() {
    setError("");
    try {
      const updated = await api(`/users/${user.id}`, {
        method: "PATCH",
        body: JSON.stringify({ profile_photo_url: profilePhotoUrl.trim(), time_zone: timeZone.trim() }),
      });
      setUser(updated);
      setTimeZone(updated.time_zone || timeZone);
    } catch (err) {
      setError(err.message);
    }
  }

  useEffect(() => {
    if (user) {
      refreshAll(user);
    }
  }, [user?.id]);

  if (!iconsLoaded) {
    return (
      <SafeAreaView style={styles.screen}>
        <StatusBar style="light" />
        <ActivityIndicator color="#c084fc" style={styles.loader} />
      </SafeAreaView>
    );
  }

  if (!user) {
    const isResetCode = authMode === "reset-code";
    const isResetPassword = authMode === "reset-password";
    return (
      <SafeAreaView style={styles.screen}>
        <StatusBar style="light" />
        <View style={styles.authPanel}>
          <Text style={styles.brand}>World Connect</Text>
          <Text style={styles.authTitle}>
            {authMode === "signup" ? "Create account" : authMode === "recover" ? "Recover password" : isResetCode ? "Enter code" : isResetPassword ? "New password" : "Log in"}
          </Text>
          {authMode === "signup" || authMode === "login" ? (
            <TextInput
              autoCapitalize="none"
              placeholderTextColor="#8f879b"
              style={styles.input}
              placeholder="Username"
              value={authUsername}
              onChangeText={setAuthUsername}
            />
          ) : null}
          {authMode === "signup" || authMode === "recover" || isResetCode ? (
            <TextInput
              autoCapitalize="none"
              keyboardType="email-address"
              placeholderTextColor="#8f879b"
              style={styles.input}
              placeholder="Email"
              value={authEmail}
              onChangeText={setAuthEmail}
            />
          ) : null}
          {authMode === "signup" || authMode === "login" ? (
            <View style={styles.passwordRow}>
              <TextInput
                secureTextEntry={!showPassword}
                placeholderTextColor="#8f879b"
                style={[styles.input, styles.passwordInput]}
                placeholder="Password"
                value={authPassword}
                onChangeText={setAuthPassword}
              />
              <Pressable style={styles.eyeButton} onPress={() => setShowPassword((value) => !value)}>
                <Ionicons name={showPassword ? "eye-off" : "eye"} size={22} color="#c084fc" />
              </Pressable>
            </View>
          ) : null}
          {isResetCode ? (
            <>
              <Text style={styles.helperText}>Enter the 6 digit code sent to your email.</Text>
              {resetDevCode ? <Text style={styles.helperText}>Dev code: {resetDevCode}</Text> : null}
              <TextInput
                keyboardType="number-pad"
                placeholderTextColor="#8f879b"
                style={styles.input}
                placeholder="6 digit code"
                value={resetCode}
                onChangeText={setResetCode}
              />
            </>
          ) : null}
          {isResetPassword ? (
            <View style={styles.passwordRow}>
              <TextInput
                secureTextEntry={!showPassword}
                placeholderTextColor="#8f879b"
                style={[styles.input, styles.passwordInput]}
                placeholder="New password"
                value={newPassword}
                onChangeText={setNewPassword}
              />
              <Pressable style={styles.eyeButton} onPress={() => setShowPassword((value) => !value)}>
                <Ionicons name={showPassword ? "eye-off" : "eye"} size={22} color="#c084fc" />
              </Pressable>
            </View>
          ) : null}
          {error ? <Text style={styles.error}>{error}</Text> : null}
          <Pressable
            style={styles.primaryButton}
            onPress={authMode === "recover" ? requestPasswordReset : isResetCode ? verifyResetCode : isResetPassword ? resetPassword : submitAuth}
            disabled={loading}
          >
            <Ionicons name={authMode === "login" ? "log-in" : authMode === "signup" ? "person-add" : "mail"} size={20} color="#ffffff" />
            <Text style={styles.primaryButtonText}>
              {loading ? "One moment" : authMode === "recover" ? "Send code" : isResetCode ? "Verify code" : isResetPassword ? "Set new password" : authMode === "login" ? "Log in" : "Sign up"}
            </Text>
          </Pressable>
          {authMode === "login" ? (
            <Pressable style={styles.textButton} onPress={() => setAuthMode("recover")}>
              <Text style={styles.textButtonLabel}>Recover password</Text>
            </Pressable>
          ) : null}
          <Pressable
            style={styles.textButton}
            onPress={() => {
              setError("");
              setResetCode("");
              setResetDevCode("");
              setNewPassword("");
              setAuthMode(authMode === "login" ? "signup" : "login");
            }}
          >
            <Text style={styles.textButtonLabel}>
              {authMode === "login" ? "Need an account? Sign up" : "Back to log in"}
            </Text>
          </Pressable>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.screen}>
      <StatusBar style="light" />
      <View style={styles.header}>
        <View>
          <Text style={styles.eyebrow}>World Connect</Text>
          <Text style={styles.title}>{tabs.find((tab) => tab.key === activeTab)?.label}</Text>
        </View>
        <Pressable style={styles.iconButton} onPress={() => refreshAll()}>
          <Ionicons name="refresh" size={22} color="#ffffff" />
        </Pressable>
      </View>

      {error ? <Text style={styles.error}>{error}</Text> : null}
      {loading ? <ActivityIndicator color="#c084fc" style={styles.loader} /> : null}

      <ScrollView contentContainerStyle={styles.content}>
        {activeTab === "home" ? (
          <>
            {feed.map((issue) => (
              <View style={styles.card} key={issue.id}>
                <Text style={styles.cardMeta}>
                  Issue #{issue.id} · {issue.newsletter_title} · {issue.author_name} · {formatDate(issue.created_at, user.time_zone)}
                </Text>
                <Text style={styles.cardTitle}>{issue.title}</Text>
                <Text style={styles.cardDescription}>{issue.body}</Text>
                {issue.photo_url ? <Image source={{ uri: issue.photo_url }} style={styles.issueImage} /> : null}
                {issue.replies?.length ? (
                  <View style={styles.replies}>
                    {issue.replies.map((reply) => (
                      <View style={styles.replyCard} key={reply.id}>
                        <Text style={styles.replyMeta}>
                          Reply #{reply.id} · {reply.author_name} · {formatDate(reply.created_at, user.time_zone)}
                        </Text>
                        <Text style={styles.replyText}>{reply.body}</Text>
                      </View>
                    ))}
                  </View>
                ) : null}
                <View style={styles.replyRow}>
                  <TextInput
                    placeholderTextColor="#8f879b"
                    style={[styles.input, styles.replyInput]}
                    placeholder="Write a reply"
                    value={replyTextByIssue[issue.id] || ""}
                    onChangeText={(text) => setReplyTextByIssue((current) => ({ ...current, [issue.id]: text }))}
                  />
                  <Pressable style={styles.smallButton} onPress={() => sendReply(issue.id)}>
                    <Ionicons name="chatbubble" size={18} color="#ffffff" />
                    <Text style={styles.smallButtonText}>Reply</Text>
                  </Pressable>
                </View>
              </View>
            ))}
            {!feed.length ? <EmptyState>Subscribe to newsletters to see issues here.</EmptyState> : null}
          </>
        ) : null}

        {activeTab === "friends" ? (
          <>
            <SectionTitle>Your friends</SectionTitle>
            {friendsData.friends.map((friend) => (
              <View style={styles.rowCard} key={friend.id}>
                <Text style={styles.rowTitle}>{friend.username}</Text>
              </View>
            ))}
            {!friendsData.friends.length ? <EmptyState>No friends yet.</EmptyState> : null}

            <SectionTitle>Requests to review</SectionTitle>
            {friendsData.incoming.map((request) => (
              <View style={styles.rowCard} key={request.id}>
                <Text style={styles.rowTitle}>{request.requester_username}</Text>
                <View style={styles.actionRow}>
                  <Pressable style={styles.acceptButton} onPress={() => updateFriendRequest(request.id, "accepted")}>
                    <Text style={styles.actionText}>Accept</Text>
                  </Pressable>
                  <Pressable style={styles.rejectButton} onPress={() => updateFriendRequest(request.id, "rejected")}>
                    <Text style={styles.actionText}>Reject</Text>
                  </Pressable>
                </View>
              </View>
            ))}
            {!friendsData.incoming.length ? <EmptyState>No pending requests.</EmptyState> : null}

            <SectionTitle>People you may know</SectionTitle>
            {friendsData.prospective.map((person) => (
              <View style={styles.rowCard} key={person.id}>
                <Text style={styles.rowTitle}>{person.username}</Text>
                <Pressable style={styles.smallButton} onPress={() => sendFriendRequest(person.id)}>
                  <Ionicons name="person-add" size={18} color="#ffffff" />
                  <Text style={styles.smallButtonText}>Add</Text>
                </Pressable>
              </View>
            ))}
            {!friendsData.prospective.length ? <EmptyState>No new people to add.</EmptyState> : null}
          </>
        ) : null}

        {activeTab === "newsletters" ? (
          <>
            <SectionTitle>Create a newsletter</SectionTitle>
            <View style={styles.card}>
              <TextInput
                placeholderTextColor="#8f879b"
                style={styles.input}
                placeholder="Newsletter title"
                value={newNewsletterTitle}
                onChangeText={setNewNewsletterTitle}
              />
              <TextInput
                placeholderTextColor="#8f879b"
                style={[styles.input, styles.textArea]}
                placeholder="What is this newsletter about?"
                value={newNewsletterDescription}
                onChangeText={setNewNewsletterDescription}
                multiline
              />
              <View style={styles.segmentedControl}>
                <Pressable
                  style={[styles.segment, newNewsletterVisibility === "public" ? styles.activeSegment : null]}
                  onPress={() => setNewNewsletterVisibility("public")}
                >
                  <Ionicons name="globe" size={17} color="#ffffff" />
                  <Text style={styles.segmentText}>Public</Text>
                </Pressable>
                <Pressable
                  style={[styles.segment, newNewsletterVisibility === "private" ? styles.activeSegment : null]}
                  onPress={() => setNewNewsletterVisibility("private")}
                >
                  <Ionicons name="lock-closed" size={17} color="#ffffff" />
                  <Text style={styles.segmentText}>Private</Text>
                </Pressable>
              </View>
              <Text style={styles.replyMeta}>Category</Text>
              <View style={styles.categoryGrid}>
                {categoryOptions.map((category) => (
                  <Pressable
                    key={category}
                    style={[styles.categoryPill, newNewsletterCategory === category ? styles.activeCategoryPill : null]}
                    onPress={() => setNewNewsletterCategory(category)}
                  >
                    <Text style={styles.categoryPillText}>{category === "custom" ? "Write your own" : category}</Text>
                  </Pressable>
                ))}
              </View>
              {newNewsletterCategory === "custom" ? (
                <TextInput
                  placeholderTextColor="#8f879b"
                  style={styles.input}
                  placeholder="Custom category name"
                  value={customNewsletterCategory}
                  onChangeText={setCustomNewsletterCategory}
                />
              ) : null}
              <Pressable style={styles.primaryButton} onPress={createNewsletter}>
                <Ionicons name="add" size={20} color="#ffffff" />
                <Text style={styles.primaryButtonText}>Create newsletter</Text>
              </Pressable>
            </View>

            <SectionTitle>Find newsletters</SectionTitle>
            {newsletters.map((newsletter) => (
              <View style={styles.card} key={newsletter.id}>
                <View style={styles.newsletterTitleRow}>
                  {newsletter.visibility === "private" ? (
                    <Ionicons name="lock-closed" size={18} color="#c084fc" />
                  ) : (
                    <Ionicons name="globe" size={18} color="#c084fc" />
                  )}
                  <Text style={styles.cardTitle}>{newsletter.title}</Text>
                </View>
                <Text style={styles.cardMeta}>
                  {newsletter.category || "friends"} · {newsletter.visibility === "private" ? "Private" : "Public"}
                  {newsletter.owner_id === user.id ? " · Owner" : ""}
                </Text>
                <Text style={styles.cardDescription}>{newsletter.description || "No description yet"}</Text>
                {newsletter.can_join || newsletter.is_subscribed ? (
                  <Pressable
                    style={newsletter.is_subscribed ? styles.secondaryButton : styles.smallButton}
                    onPress={() => toggleSubscription(newsletter)}
                  >
                    <Ionicons
                      name={newsletter.is_subscribed ? "checkmark-circle" : "add-circle"}
                      size={18}
                      color="#ffffff"
                    />
                    <Text style={newsletter.is_subscribed ? styles.secondaryButtonText : styles.smallButtonText}>
                      {newsletter.is_subscribed ? "Subscribed" : "Subscribe"}
                    </Text>
                  </Pressable>
                ) : (
                  <Text style={styles.helperText}>Invitation required to join.</Text>
                )}
                {newsletter.can_invite ? (
                  <View style={styles.invitePanel}>
                    <Text style={styles.replyMeta}>Invite people</Text>
                    {friendsData.friends.map((person) => (
                      <View style={styles.inviteRow} key={`${newsletter.id}-${person.id}`}>
                        <Text style={styles.inviteName}>{person.username}</Text>
                        <Pressable style={styles.secondaryButton} onPress={() => inviteToNewsletter(newsletter, person.id)}>
                          <Ionicons name="mail" size={17} color="#ffffff" />
                          <Text style={styles.secondaryButtonText}>Invite</Text>
                        </Pressable>
                      </View>
                    ))}
                    {!friendsData.friends.length ? (
                      <Text style={styles.helperText}>Add friends before inviting people.</Text>
                    ) : null}
                  </View>
                ) : null}
              </View>
            ))}
            {!newsletters.length ? <EmptyState>No newsletters yet.</EmptyState> : null}
          </>
        ) : null}

        {activeTab === "profile" ? (
          <View style={styles.card}>
            {user.profile_photo_url ? (
              <Image source={{ uri: user.profile_photo_url }} style={styles.avatar} />
            ) : (
              <View style={styles.avatarPlaceholder}>
                <Ionicons name="person" size={36} color="#c084fc" />
              </View>
            )}
            <Text style={styles.profileName}>{user.username}</Text>
            <Text style={styles.profileDetail}>{user.email}</Text>
            <TextInput
              autoCapitalize="none"
              placeholderTextColor="#8f879b"
              style={styles.input}
              placeholder="Time zone, e.g. Europe/Lisbon"
              value={timeZone}
              onChangeText={setTimeZone}
            />
            <Pressable style={styles.secondaryButton} onPress={chooseProfilePhoto} disabled={uploading}>
              <Ionicons name="image" size={18} color="#ffffff" />
              <Text style={styles.secondaryButtonText}>{uploading ? "Uploading" : "Upload JPG or PNG"}</Text>
            </Pressable>
            <Pressable style={styles.primaryButton} onPress={saveProfile}>
              <Ionicons name="save" size={20} color="#ffffff" />
              <Text style={styles.primaryButtonText}>Save updates</Text>
            </Pressable>
            <Pressable style={styles.textButton} onPress={() => setUser(null)}>
              <Text style={styles.textButtonLabel}>Log out</Text>
            </Pressable>
          </View>
        ) : null}
      </ScrollView>

      {showComposer ? (
        <View style={styles.composer}>
          <Text style={styles.composerTitle}>New issue</Text>
          <TextInput
            placeholderTextColor="#8f879b"
            style={styles.input}
            placeholder={subscribedNewsletters.length ? `Newsletter ID (${subscribedNewsletters[0].id})` : "Subscribe to a newsletter first"}
            value={issueNewsletterId}
            onChangeText={setIssueNewsletterId}
            keyboardType="number-pad"
          />
          <TextInput
            placeholderTextColor="#8f879b"
            style={styles.input}
            placeholder="Issue title"
            value={issueTitle}
            onChangeText={setIssueTitle}
          />
          <TextInput
            placeholderTextColor="#8f879b"
            style={[styles.input, styles.textArea]}
            placeholder="Write the issue text"
            value={issueBody}
            onChangeText={setIssueBody}
            multiline
          />
          {issuePhotoUrl ? <Image source={{ uri: issuePhotoUrl }} style={styles.issueImage} /> : null}
          <Pressable style={styles.secondaryButton} onPress={chooseIssuePhoto} disabled={uploading}>
            <Ionicons name="image" size={18} color="#ffffff" />
            <Text style={styles.secondaryButtonText}>{uploading ? "Uploading" : "Add JPG or PNG"}</Text>
          </Pressable>
          <View style={styles.actionRow}>
            <Pressable style={styles.secondaryButton} onPress={() => setShowComposer(false)}>
              <Text style={styles.secondaryButtonText}>Cancel</Text>
            </Pressable>
            <Pressable style={styles.smallButton} onPress={createIssue}>
              <Ionicons name="send" size={18} color="#ffffff" />
              <Text style={styles.smallButtonText}>Post</Text>
            </Pressable>
          </View>
        </View>
      ) : null}

      {activeTab === "home" && !showComposer ? (
        <Pressable style={styles.fab} onPress={() => setShowComposer(true)}>
          <Ionicons name="add" size={30} color="#ffffff" />
        </Pressable>
      ) : null}

      <View style={styles.tabBar}>
        {tabs.map((tab) => {
          const active = activeTab === tab.key;
          return (
            <Pressable style={styles.tabButton} key={tab.key} onPress={() => setActiveTab(tab.key)}>
              <Ionicons name={tab.icon} size={22} color={active ? "#c084fc" : "#8f879b"} />
              <Text style={[styles.tabLabel, active ? styles.activeTabLabel : null]}>{tab.label}</Text>
            </Pressable>
          );
        })}
      </View>
    </SafeAreaView>
  );
}

const colors = {
  bg: "#050507",
  surface: "#121017",
  surface2: "#1b1623",
  border: "#33273f",
  text: "#ffffff",
  muted: "#c9bfd6",
  dim: "#8f879b",
  purple: "#8b5cf6",
  purpleLight: "#c084fc",
  danger: "#ef4444",
};

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: colors.bg,
    paddingHorizontal: 28,
  },
  authPanel: {
    alignSelf: "center",
    gap: 12,
    justifyContent: "center",
    maxWidth: 420,
    minHeight: "92%",
    width: "100%",
  },
  brand: {
    color: colors.purpleLight,
    fontSize: 18,
    fontWeight: "700",
  },
  authTitle: {
    color: colors.text,
    fontSize: 34,
    fontWeight: "800",
    marginBottom: 8,
  },
  header: {
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "space-between",
    paddingBottom: 14,
    paddingTop: 18,
  },
  eyebrow: {
    color: colors.purpleLight,
    fontSize: 13,
    fontWeight: "700",
    textTransform: "uppercase",
  },
  title: {
    color: colors.text,
    fontSize: 30,
    fontWeight: "800",
  },
  iconButton: {
    alignItems: "center",
    backgroundColor: colors.surface2,
    borderRadius: 8,
    height: 42,
    justifyContent: "center",
    width: 42,
  },
  content: {
    gap: 12,
    paddingHorizontal: 5,
    paddingBottom: 110,
    paddingTop: 5,
  },
  sectionTitle: {
    color: colors.text,
    fontSize: 19,
    fontWeight: "800",
    marginTop: 12,
  },
  card: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 8,
    borderWidth: 1,
    gap: 10,
    padding: 16,
  },
  rowCard: {
    alignItems: "center",
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: "row",
    justifyContent: "space-between",
    minHeight: 58,
    padding: 14,
  },
  rowTitle: {
    color: colors.text,
    fontSize: 16,
    fontWeight: "700",
  },
  cardMeta: {
    color: colors.purpleLight,
    fontSize: 13,
    fontWeight: "700",
  },
  cardTitle: {
    color: colors.text,
    fontSize: 20,
    fontWeight: "800",
  },
  cardDescription: {
    color: colors.muted,
    fontSize: 15,
    lineHeight: 22,
  },
  issueImage: {
    aspectRatio: 1.7,
    backgroundColor: colors.surface2,
    borderRadius: 8,
    width: "100%",
  },
  replies: {
    borderTopColor: colors.border,
    borderTopWidth: 1,
    gap: 8,
    paddingTop: 10,
  },
  replyCard: {
    backgroundColor: colors.surface2,
    borderRadius: 8,
    gap: 4,
    padding: 10,
  },
  replyMeta: {
    color: colors.purpleLight,
    fontSize: 12,
    fontWeight: "700",
  },
  replyText: {
    color: colors.text,
    fontSize: 14,
    lineHeight: 20,
  },
  newsletterTitleRow: {
    alignItems: "center",
    flexDirection: "row",
    gap: 8,
  },
  segmentedControl: {
    backgroundColor: colors.surface2,
    borderColor: colors.border,
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: "row",
    gap: 6,
    padding: 4,
  },
  segment: {
    alignItems: "center",
    borderRadius: 6,
    flex: 1,
    flexDirection: "row",
    gap: 6,
    justifyContent: "center",
    minHeight: 40,
  },
  activeSegment: {
    backgroundColor: colors.purple,
  },
  segmentText: {
    color: colors.text,
    fontSize: 14,
    fontWeight: "800",
  },
  categoryGrid: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 8,
  },
  categoryPill: {
    backgroundColor: colors.surface2,
    borderColor: colors.border,
    borderRadius: 8,
    borderWidth: 1,
    paddingHorizontal: 12,
    paddingVertical: 9,
  },
  activeCategoryPill: {
    backgroundColor: colors.purple,
  },
  categoryPillText: {
    color: colors.text,
    fontSize: 14,
    fontWeight: "800",
  },
  invitePanel: {
    borderTopColor: colors.border,
    borderTopWidth: 1,
    gap: 8,
    paddingTop: 10,
  },
  inviteRow: {
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "space-between",
    gap: 10,
  },
  inviteName: {
    color: colors.text,
    flex: 1,
    fontSize: 14,
    fontWeight: "700",
  },
  input: {
    backgroundColor: colors.surface2,
    borderColor: colors.border,
    borderRadius: 8,
    borderWidth: 1,
    color: colors.text,
    fontSize: 16,
    paddingHorizontal: 14,
    paddingVertical: 12,
  },
  passwordRow: {
    flexDirection: "row",
    gap: 8,
  },
  passwordInput: {
    flex: 1,
  },
  eyeButton: {
    alignItems: "center",
    backgroundColor: colors.surface2,
    borderColor: colors.border,
    borderRadius: 8,
    borderWidth: 1,
    justifyContent: "center",
    width: 50,
  },
  textArea: {
    minHeight: 82,
    textAlignVertical: "top",
  },
  replyRow: {
    alignItems: "center",
    flexDirection: "row",
    gap: 8,
  },
  replyInput: {
    flex: 1,
  },
  primaryButton: {
    alignItems: "center",
    backgroundColor: colors.purple,
    borderRadius: 8,
    flexDirection: "row",
    gap: 8,
    justifyContent: "center",
    minHeight: 48,
    paddingHorizontal: 14,
  },
  primaryButtonText: {
    color: colors.text,
    fontSize: 16,
    fontWeight: "800",
  },
  smallButton: {
    alignItems: "center",
    alignSelf: "flex-start",
    backgroundColor: colors.purple,
    borderRadius: 8,
    flexDirection: "row",
    gap: 6,
    justifyContent: "center",
    minHeight: 40,
    paddingHorizontal: 12,
  },
  smallButtonText: {
    color: colors.text,
    fontSize: 14,
    fontWeight: "800",
  },
  secondaryButton: {
    alignItems: "center",
    alignSelf: "flex-start",
    backgroundColor: colors.surface2,
    borderColor: colors.border,
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: "row",
    gap: 6,
    justifyContent: "center",
    minHeight: 40,
    paddingHorizontal: 12,
  },
  secondaryButtonText: {
    color: colors.text,
    fontSize: 14,
    fontWeight: "800",
  },
  acceptButton: {
    backgroundColor: colors.purple,
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 9,
  },
  rejectButton: {
    backgroundColor: colors.danger,
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 9,
  },
  actionText: {
    color: colors.text,
    fontWeight: "800",
  },
  actionRow: {
    alignItems: "center",
    flexDirection: "row",
    gap: 8,
  },
  textButton: {
    alignItems: "center",
    minHeight: 44,
    justifyContent: "center",
  },
  textButtonLabel: {
    color: colors.purpleLight,
    fontSize: 15,
    fontWeight: "800",
  },
  error: {
    color: "#fca5a5",
    marginBottom: 10,
  },
  loader: {
    marginBottom: 8,
  },
  empty: {
    color: colors.dim,
    paddingVertical: 10,
    textAlign: "center",
  },
  avatar: {
    alignSelf: "center",
    borderRadius: 45,
    height: 90,
    width: 90,
  },
  avatarPlaceholder: {
    alignItems: "center",
    alignSelf: "center",
    backgroundColor: colors.surface2,
    borderRadius: 45,
    height: 90,
    justifyContent: "center",
    width: 90,
  },
  profileName: {
    color: colors.text,
    fontSize: 24,
    fontWeight: "800",
    textAlign: "center",
  },
  profileDetail: {
    color: colors.muted,
    fontSize: 14,
    textAlign: "center",
  },
  helperText: {
    color: colors.muted,
    fontSize: 14,
    lineHeight: 20,
  },
  composer: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 8,
    borderWidth: 1,
    bottom: 88,
    gap: 10,
    left: 28,
    padding: 14,
    position: "absolute",
    right: 28,
  },
  composerTitle: {
    color: colors.text,
    fontSize: 18,
    fontWeight: "800",
  },
  fab: {
    alignItems: "center",
    backgroundColor: colors.purple,
    borderRadius: 28,
    bottom: 86,
    height: 56,
    justifyContent: "center",
    position: "absolute",
    right: 28,
    width: 56,
  },
  tabBar: {
    alignItems: "center",
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 8,
    borderWidth: 1,
    bottom: 16,
    flexDirection: "row",
    justifyContent: "space-around",
    left: 28,
    minHeight: 64,
    paddingHorizontal: 4,
    position: "absolute",
    right: 28,
  },
  tabButton: {
    alignItems: "center",
    gap: 3,
    minWidth: 70,
    paddingVertical: 8,
  },
  tabLabel: {
    color: colors.dim,
    fontSize: 12,
    fontWeight: "700",
  },
  activeTabLabel: {
    color: colors.purpleLight,
  },
});
