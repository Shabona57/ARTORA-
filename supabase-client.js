import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SUPABASE_URL, SUPABASE_ANON_KEY } from "./supabase-config.js";

if (SUPABASE_URL.startsWith("YOUR_") || SUPABASE_ANON_KEY.startsWith("YOUR_")) {
  console.warn("ARTORA: Add your Supabase URL and anon/public key in supabase-config.js.");
}

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

export async function signUp({ email, password, username, displayName }) {
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: { data: { username, display_name: displayName || username } }
  });
  if (error) throw error;
  return data;
}

export async function signIn({ email, password }) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) throw error;
  return data;
}

export async function signOut() {
  const { error } = await supabase.auth.signOut();
  if (error) throw error;
}

export async function getCurrentUser() {
  const { data, error } = await supabase.auth.getUser();
  if (error) throw error;
  return data.user;
}

export async function uploadArtwork({ file, title, description = "", category = "Painting", technique = "" }) {
  const user = await getCurrentUser();
  if (!user) throw new Error("Please sign in before uploading artwork.");
  if (!file || !file.type.startsWith("image/")) throw new Error("Choose a valid image file.");
  if (file.size > 10 * 1024 * 1024) throw new Error("Image must be 10 MB or smaller.");

  const safeName = file.name.replace(/[^a-zA-Z0-9._-]/g, "-");
  const filePath = `${user.id}/${crypto.randomUUID()}-${safeName}`;
  const { error: uploadError } = await supabase.storage
    .from("artwork-images")
    .upload(filePath, file, { contentType: file.type, upsert: false });
  if (uploadError) throw uploadError;

  const { data: publicData } = supabase.storage.from("artwork-images").getPublicUrl(filePath);
  const { data, error } = await supabase.from("artworks").insert({
    user_id: user.id, title, description, category, technique, image_url: publicData.publicUrl
  }).select().single();

  if (error) {
    await supabase.storage.from("artwork-images").remove([filePath]);
    throw error;
  }
  return data;
}

export async function fetchArtworks({ category = "All", search = "" } = {}) {
  let query = supabase.from("artworks")
    .select("id,title,description,image_url,category,technique,created_at,user_id,profiles(username,display_name,avatar_url),likes(count)")
    .order("created_at", { ascending: false });
  if (category !== "All") query = query.eq("category", category);
  if (search.trim()) query = query.ilike("title", `%${search.trim()}%`);
  const { data, error } = await query;
  if (error) throw error;
  return data;
}

export async function toggleLike(artworkId) {
  const user = await getCurrentUser();
  if (!user) throw new Error("Please sign in to like artwork.");
  const { data: existing, error: findError } = await supabase.from("likes")
    .select("artwork_id").eq("user_id", user.id).eq("artwork_id", artworkId).maybeSingle();
  if (findError) throw findError;
  if (existing) {
    const { error } = await supabase.from("likes").delete()
      .eq("user_id", user.id).eq("artwork_id", artworkId);
    if (error) throw error;
    return false;
  }
  const { error } = await supabase.from("likes").insert({ user_id: user.id, artwork_id: artworkId });
  if (error) throw error;
  return true;
}

export async function toggleFollow(artistId) {
  const user = await getCurrentUser();
  if (!user) throw new Error("Please sign in to follow artists.");
  if (user.id === artistId) throw new Error("You cannot follow your own profile.");
  const { data: existing, error: findError } = await supabase.from("follows")
    .select("follower_id").eq("follower_id", user.id).eq("following_id", artistId).maybeSingle();
  if (findError) throw findError;
  if (existing) {
    const { error } = await supabase.from("follows").delete()
      .eq("follower_id", user.id).eq("following_id", artistId);
    if (error) throw error;
    return false;
  }
  const { error } = await supabase.from("follows").insert({ follower_id: user.id, following_id: artistId });
  if (error) throw error;
  return true;
}
