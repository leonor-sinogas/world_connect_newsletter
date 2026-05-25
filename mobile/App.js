import { useEffect, useState } from "react";
import {
  ActivityIndicator,
  FlatList,
  Pressable,
  SafeAreaView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";
import { StatusBar } from "expo-status-bar";
import { Ionicons } from "@expo/vector-icons";

const API_BASE_URL = "http://localhost:8000";

export default function App() {
  const [newsletters, setNewsletters] = useState([]);
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  async function loadNewsletters() {
    setError("");
    setLoading(true);
    try {
      const response = await fetch(`${API_BASE_URL}/newsletters`);
      if (!response.ok) {
        throw new Error("Could not load newsletters");
      }
      setNewsletters(await response.json());
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  async function createNewsletter() {
    if (!title.trim()) {
      return;
    }

    setError("");
    setSaving(true);
    try {
      const response = await fetch(`${API_BASE_URL}/newsletters`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title: title.trim(), description: description.trim() }),
      });
      if (!response.ok) {
        throw new Error("Could not create newsletter");
      }
      setTitle("");
      setDescription("");
      await loadNewsletters();
    } catch (err) {
      setError(err.message);
    } finally {
      setSaving(false);
    }
  }

  useEffect(() => {
    loadNewsletters();
  }, []);

  return (
    <SafeAreaView style={styles.screen}>
      <StatusBar style="dark" />
      <View style={styles.header}>
        <Text style={styles.title}>Newsletter</Text>
        <Pressable style={styles.iconButton} onPress={loadNewsletters}>
          <Ionicons name="refresh" size={22} color="#18343f" />
        </Pressable>
      </View>

      <View style={styles.form}>
        <TextInput
          style={styles.input}
          placeholder="Newsletter title"
          value={title}
          onChangeText={setTitle}
        />
        <TextInput
          style={[styles.input, styles.textArea]}
          placeholder="Short description"
          value={description}
          onChangeText={setDescription}
          multiline
        />
        <Pressable style={styles.primaryButton} onPress={createNewsletter} disabled={saving}>
          <Ionicons name="add" size={20} color="#ffffff" />
          <Text style={styles.primaryButtonText}>{saving ? "Creating" : "Create"}</Text>
        </Pressable>
      </View>

      {error ? <Text style={styles.error}>{error}</Text> : null}

      {loading ? (
        <ActivityIndicator style={styles.loader} />
      ) : (
        <FlatList
          data={newsletters}
          keyExtractor={(item) => String(item.id)}
          contentContainerStyle={styles.list}
          renderItem={({ item }) => (
            <View style={styles.card}>
              <Text style={styles.cardTitle}>{item.title}</Text>
              <Text style={styles.cardDescription}>{item.description || "No description yet"}</Text>
            </View>
          )}
          ListEmptyComponent={<Text style={styles.empty}>No newsletters yet.</Text>}
        />
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: "#f6f8f5",
    paddingHorizontal: 20,
  },
  header: {
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "space-between",
    paddingBottom: 16,
    paddingTop: 18,
  },
  title: {
    color: "#18343f",
    fontSize: 30,
    fontWeight: "700",
  },
  iconButton: {
    alignItems: "center",
    backgroundColor: "#e5ece7",
    borderRadius: 8,
    height: 42,
    justifyContent: "center",
    width: 42,
  },
  form: {
    gap: 10,
    paddingBottom: 18,
  },
  input: {
    backgroundColor: "#ffffff",
    borderColor: "#d9e0dc",
    borderRadius: 8,
    borderWidth: 1,
    color: "#18343f",
    fontSize: 16,
    paddingHorizontal: 14,
    paddingVertical: 12,
  },
  textArea: {
    minHeight: 76,
    textAlignVertical: "top",
  },
  primaryButton: {
    alignItems: "center",
    backgroundColor: "#167c80",
    borderRadius: 8,
    flexDirection: "row",
    gap: 8,
    justifyContent: "center",
    minHeight: 48,
  },
  primaryButtonText: {
    color: "#ffffff",
    fontSize: 16,
    fontWeight: "700",
  },
  error: {
    color: "#b42318",
    marginBottom: 12,
  },
  loader: {
    marginTop: 40,
  },
  list: {
    gap: 10,
    paddingBottom: 28,
  },
  card: {
    backgroundColor: "#ffffff",
    borderColor: "#d9e0dc",
    borderRadius: 8,
    borderWidth: 1,
    padding: 16,
  },
  cardTitle: {
    color: "#18343f",
    fontSize: 18,
    fontWeight: "700",
    marginBottom: 6,
  },
  cardDescription: {
    color: "#5a6b70",
    fontSize: 15,
    lineHeight: 21,
  },
  empty: {
    color: "#5a6b70",
    marginTop: 24,
    textAlign: "center",
  },
});

