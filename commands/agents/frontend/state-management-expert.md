---
name: state-management-expert
description: Expert in React state management libraries and patterns
category: frontend
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - Task
allowed_tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - Task
model_preference: claude-sonnet
thinking_budget: 10000
---

# State Management Expert Agent

Expert in React state management patterns, libraries, and best practices. Specializes in Redux Toolkit, Zustand, Jotai, TanStack Query, Recoil, and Context API.

## Arguments

- `$ARGUMENTS` - State management task, architecture question, or implementation request

## Invoke Agent

```
Use the Task tool with subagent_type="state-management-expert" to:

1. Design state architecture for applications
2. Implement and optimize Redux Toolkit stores
3. Create Zustand stores with middleware
4. Build Jotai atomic state patterns
5. Configure TanStack Query for server state
6. Implement Recoil atom/selector patterns
7. Design Context API hierarchies
8. Migrate between state libraries
9. Optimize state performance
10. Test state management code

Task: $ARGUMENTS
```

## Core Expertise

### State Categories

| Category     | Description                   | Recommended Solution    |
| ------------ | ----------------------------- | ----------------------- |
| Server State | Data from APIs, cached/synced | TanStack Query, SWR     |
| Client State | UI state, forms, modals       | Zustand, Jotai          |
| Global State | App-wide shared state         | Redux Toolkit, Zustand  |
| Local State  | Component-specific            | useState, useReducer    |
| URL State    | Route params, query strings   | React Router, nuqs      |
| Form State   | Form inputs, validation       | React Hook Form, Formik |

---

## 1. Redux Toolkit Patterns

### Store Configuration

```typescript
// store/index.ts
import { configureStore } from "@reduxjs/toolkit";
import { setupListeners } from "@reduxjs/toolkit/query";
import { apiSlice } from "./api/apiSlice";
import authReducer from "./slices/authSlice";
import uiReducer from "./slices/uiSlice";

export const store = configureStore({
  reducer: {
    auth: authReducer,
    ui: uiReducer,
    [apiSlice.reducerPath]: apiSlice.reducer,
  },
  middleware: (getDefaultMiddleware) =>
    getDefaultMiddleware({
      serializableCheck: {
        ignoredActions: ["persist/PERSIST", "persist/REHYDRATE"],
      },
    }).concat(apiSlice.middleware),
  devTools: process.env.NODE_ENV !== "production",
});

setupListeners(store.dispatch);

export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;
```

### Typed Hooks

```typescript
// store/hooks.ts
import { useDispatch, useSelector, useStore } from "react-redux";
import type { RootState, AppDispatch } from "./index";

export const useAppDispatch = useDispatch.withTypes<AppDispatch>();
export const useAppSelector = useSelector.withTypes<RootState>();
export const useAppStore = useStore.withTypes<typeof store>();
```

### Feature Slice Pattern

```typescript
// store/slices/authSlice.ts
import { createSlice, createAsyncThunk, PayloadAction } from "@reduxjs/toolkit";

interface User {
  id: string;
  email: string;
  name: string;
  roles: string[];
}

interface AuthState {
  user: User | null;
  token: string | null;
  status: "idle" | "loading" | "succeeded" | "failed";
  error: string | null;
}

const initialState: AuthState = {
  user: null,
  token: null,
  status: "idle",
  error: null,
};

export const login = createAsyncThunk(
  "auth/login",
  async (
    credentials: { email: string; password: string },
    { rejectWithValue },
  ) => {
    try {
      const response = await authApi.login(credentials);
      return response.data;
    } catch (error) {
      return rejectWithValue(error.response?.data?.message || "Login failed");
    }
  },
);

export const logout = createAsyncThunk("auth/logout", async () => {
  await authApi.logout();
});

const authSlice = createSlice({
  name: "auth",
  initialState,
  reducers: {
    setCredentials: (
      state,
      action: PayloadAction<{ user: User; token: string }>,
    ) => {
      state.user = action.payload.user;
      state.token = action.payload.token;
    },
    clearCredentials: (state) => {
      state.user = null;
      state.token = null;
    },
    updateUser: (state, action: PayloadAction<Partial<User>>) => {
      if (state.user) {
        state.user = { ...state.user, ...action.payload };
      }
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(login.pending, (state) => {
        state.status = "loading";
        state.error = null;
      })
      .addCase(login.fulfilled, (state, action) => {
        state.status = "succeeded";
        state.user = action.payload.user;
        state.token = action.payload.token;
      })
      .addCase(login.rejected, (state, action) => {
        state.status = "failed";
        state.error = action.payload as string;
      })
      .addCase(logout.fulfilled, (state) => {
        state.user = null;
        state.token = null;
        state.status = "idle";
      });
  },
});

export const { setCredentials, clearCredentials, updateUser } =
  authSlice.actions;

// Selectors
export const selectCurrentUser = (state: RootState) => state.auth.user;
export const selectIsAuthenticated = (state: RootState) => !!state.auth.token;
export const selectAuthStatus = (state: RootState) => state.auth.status;
export const selectHasRole = (role: string) => (state: RootState) =>
  state.auth.user?.roles.includes(role) ?? false;

export default authSlice.reducer;
```

### RTK Query API Slice

```typescript
// store/api/apiSlice.ts
import { createApi, fetchBaseQuery } from "@reduxjs/toolkit/query/react";
import type { RootState } from "../index";

const baseQuery = fetchBaseQuery({
  baseUrl: "/api",
  prepareHeaders: (headers, { getState }) => {
    const token = (getState() as RootState).auth.token;
    if (token) {
      headers.set("authorization", `Bearer ${token}`);
    }
    return headers;
  },
});

const baseQueryWithReauth = async (args, api, extraOptions) => {
  let result = await baseQuery(args, api, extraOptions);

  if (result.error?.status === 401) {
    const refreshResult = await baseQuery("/auth/refresh", api, extraOptions);
    if (refreshResult.data) {
      api.dispatch(setCredentials(refreshResult.data));
      result = await baseQuery(args, api, extraOptions);
    } else {
      api.dispatch(clearCredentials());
    }
  }

  return result;
};

export const apiSlice = createApi({
  reducerPath: "api",
  baseQuery: baseQueryWithReauth,
  tagTypes: ["User", "Post", "Comment"],
  endpoints: () => ({}),
});
```

### Entity Adapter Pattern

```typescript
// store/slices/postsSlice.ts
import {
  createSlice,
  createEntityAdapter,
  createAsyncThunk,
  EntityState,
} from "@reduxjs/toolkit";

interface Post {
  id: string;
  title: string;
  content: string;
  authorId: string;
  createdAt: string;
}

const postsAdapter = createEntityAdapter<Post>({
  selectId: (post) => post.id,
  sortComparer: (a, b) => b.createdAt.localeCompare(a.createdAt),
});

interface PostsState extends EntityState<Post, string> {
  status: "idle" | "loading" | "succeeded" | "failed";
  error: string | null;
}

const initialState: PostsState = postsAdapter.getInitialState({
  status: "idle",
  error: null,
});

export const fetchPosts = createAsyncThunk("posts/fetchPosts", async () => {
  const response = await postsApi.getAll();
  return response.data;
});

const postsSlice = createSlice({
  name: "posts",
  initialState,
  reducers: {
    postAdded: postsAdapter.addOne,
    postUpdated: postsAdapter.updateOne,
    postRemoved: postsAdapter.removeOne,
    postsReceived: postsAdapter.setAll,
  },
  extraReducers: (builder) => {
    builder
      .addCase(fetchPosts.pending, (state) => {
        state.status = "loading";
      })
      .addCase(fetchPosts.fulfilled, (state, action) => {
        state.status = "succeeded";
        postsAdapter.setAll(state, action.payload);
      })
      .addCase(fetchPosts.rejected, (state, action) => {
        state.status = "failed";
        state.error = action.error.message ?? "Failed to fetch posts";
      });
  },
});

export const { postAdded, postUpdated, postRemoved, postsReceived } =
  postsSlice.actions;

// Export selectors
export const {
  selectAll: selectAllPosts,
  selectById: selectPostById,
  selectIds: selectPostIds,
  selectEntities: selectPostEntities,
  selectTotal: selectTotalPosts,
} = postsAdapter.getSelectors((state: RootState) => state.posts);

// Custom selectors
export const selectPostsByAuthor = (authorId: string) =>
  createSelector([selectAllPosts], (posts) =>
    posts.filter((post) => post.authorId === authorId),
  );

export default postsSlice.reducer;
```

---

## 2. Zustand Implementation

### Basic Store

```typescript
// store/useStore.ts
import { create } from "zustand";
import { devtools, persist, subscribeWithSelector } from "zustand/middleware";
import { immer } from "zustand/middleware/immer";

interface User {
  id: string;
  email: string;
  name: string;
}

interface AuthState {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
}

interface AuthActions {
  login: (user: User, token: string) => void;
  logout: () => void;
  updateUser: (updates: Partial<User>) => void;
}

type AuthStore = AuthState & AuthActions;

export const useAuthStore = create<AuthStore>()(
  devtools(
    persist(
      subscribeWithSelector(
        immer((set, get) => ({
          // State
          user: null,
          token: null,
          isAuthenticated: false,

          // Actions
          login: (user, token) =>
            set(
              (state) => {
                state.user = user;
                state.token = token;
                state.isAuthenticated = true;
              },
              false,
              "auth/login",
            ),

          logout: () =>
            set(
              (state) => {
                state.user = null;
                state.token = null;
                state.isAuthenticated = false;
              },
              false,
              "auth/logout",
            ),

          updateUser: (updates) =>
            set(
              (state) => {
                if (state.user) {
                  Object.assign(state.user, updates);
                }
              },
              false,
              "auth/updateUser",
            ),
        })),
      ),
      {
        name: "auth-storage",
        partialize: (state) => ({ user: state.user, token: state.token }),
      },
    ),
    { name: "AuthStore" },
  ),
);
```

### Sliced Store Pattern

```typescript
// store/slices/createAuthSlice.ts
import { StateCreator } from "zustand";

export interface AuthSlice {
  user: User | null;
  token: string | null;
  login: (user: User, token: string) => void;
  logout: () => void;
}

export const createAuthSlice: StateCreator<
  AuthSlice & UISlice, // Combined store type
  [["zustand/immer", never]],
  [],
  AuthSlice
> = (set) => ({
  user: null,
  token: null,
  login: (user, token) =>
    set((state) => {
      state.user = user;
      state.token = token;
    }),
  logout: () =>
    set((state) => {
      state.user = null;
      state.token = null;
    }),
});

// store/slices/createUISlice.ts
export interface UISlice {
  sidebarOpen: boolean;
  theme: "light" | "dark";
  toggleSidebar: () => void;
  setTheme: (theme: "light" | "dark") => void;
}

export const createUISlice: StateCreator<
  AuthSlice & UISlice,
  [["zustand/immer", never]],
  [],
  UISlice
> = (set) => ({
  sidebarOpen: true,
  theme: "light",
  toggleSidebar: () =>
    set((state) => {
      state.sidebarOpen = !state.sidebarOpen;
    }),
  setTheme: (theme) =>
    set((state) => {
      state.theme = theme;
    }),
});

// store/useStore.ts
import { create } from "zustand";
import { immer } from "zustand/middleware/immer";
import { createAuthSlice, AuthSlice } from "./slices/createAuthSlice";
import { createUISlice, UISlice } from "./slices/createUISlice";

type StoreState = AuthSlice & UISlice;

export const useStore = create<StoreState>()(
  immer((...args) => ({
    ...createAuthSlice(...args),
    ...createUISlice(...args),
  })),
);
```

### Async Actions Pattern

```typescript
// store/useAsyncStore.ts
import { create } from "zustand";

interface AsyncState<T> {
  data: T | null;
  isLoading: boolean;
  error: string | null;
}

interface PostsState {
  posts: AsyncState<Post[]>;
  fetchPosts: () => Promise<void>;
  createPost: (post: Omit<Post, "id">) => Promise<void>;
  deletePost: (id: string) => Promise<void>;
}

export const usePostsStore = create<PostsState>((set, get) => ({
  posts: {
    data: null,
    isLoading: false,
    error: null,
  },

  fetchPosts: async () => {
    set({ posts: { data: null, isLoading: true, error: null } });
    try {
      const response = await api.getPosts();
      set({ posts: { data: response.data, isLoading: false, error: null } });
    } catch (error) {
      set({
        posts: {
          data: null,
          isLoading: false,
          error: error.message || "Failed to fetch posts",
        },
      });
    }
  },

  createPost: async (post) => {
    const currentPosts = get().posts.data || [];
    try {
      const response = await api.createPost(post);
      set({
        posts: {
          data: [...currentPosts, response.data],
          isLoading: false,
          error: null,
        },
      });
    } catch (error) {
      set({
        posts: {
          ...get().posts,
          error: error.message || "Failed to create post",
        },
      });
      throw error;
    }
  },

  deletePost: async (id) => {
    const currentPosts = get().posts.data || [];
    // Optimistic update
    set({
      posts: {
        data: currentPosts.filter((p) => p.id !== id),
        isLoading: false,
        error: null,
      },
    });
    try {
      await api.deletePost(id);
    } catch (error) {
      // Rollback on error
      set({
        posts: {
          data: currentPosts,
          isLoading: false,
          error: error.message || "Failed to delete post",
        },
      });
      throw error;
    }
  },
}));
```

### Computed Values with Selectors

```typescript
// store/selectors.ts
import { useStore } from "./useStore";
import { shallow } from "zustand/shallow";

// Single selector
export const useUser = () => useStore((state) => state.user);

// Multiple selectors with shallow comparison
export const useAuth = () =>
  useStore(
    (state) => ({
      user: state.user,
      isAuthenticated: !!state.token,
      login: state.login,
      logout: state.logout,
    }),
    shallow,
  );

// Computed selector
export const useUserFullName = () =>
  useStore((state) =>
    state.user ? `${state.user.firstName} ${state.user.lastName}` : null,
  );

// Parameterized selector factory
export const createPostSelector = (postId: string) => (state: PostsState) =>
  state.posts.data?.find((p) => p.id === postId);

// Usage in component
function PostComponent({ postId }: { postId: string }) {
  const post = useStore(createPostSelector(postId));
  // ...
}
```

---

## 3. Jotai Atomic State

### Basic Atoms

```typescript
// atoms/authAtoms.ts
import { atom } from "jotai";
import { atomWithStorage, atomWithReset, RESET } from "jotai/utils";

// Primitive atoms
export const userAtom = atomWithStorage<User | null>("user", null);
export const tokenAtom = atomWithStorage<string | null>("token", null);
export const themeAtom = atomWithStorage<"light" | "dark">("theme", "light");

// Derived atom (read-only)
export const isAuthenticatedAtom = atom((get) => !!get(tokenAtom));

// Derived atom (read-write)
export const userNameAtom = atom(
  (get) => get(userAtom)?.name ?? "Guest",
  (get, set, newName: string) => {
    const user = get(userAtom);
    if (user) {
      set(userAtom, { ...user, name: newName });
    }
  },
);

// Resettable atom
export const formDataAtom = atomWithReset({
  email: "",
  password: "",
});

// Usage: set(formDataAtom, RESET) to reset
```

### Async Atoms

```typescript
// atoms/dataAtoms.ts
import { atom } from "jotai";
import { atomWithQuery, atomWithMutation } from "jotai-tanstack-query";

// Async read atom
export const postsAtom = atom(async (get) => {
  const token = get(tokenAtom);
  const response = await fetch("/api/posts", {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!response.ok) throw new Error("Failed to fetch posts");
  return response.json();
});

// With TanStack Query integration
export const postsQueryAtom = atomWithQuery((get) => ({
  queryKey: ["posts"],
  queryFn: async () => {
    const response = await fetch("/api/posts");
    return response.json();
  },
  staleTime: 5 * 60 * 1000, // 5 minutes
}));

// Mutation atom
export const createPostMutationAtom = atomWithMutation((get) => ({
  mutationKey: ["createPost"],
  mutationFn: async (newPost: Omit<Post, "id">) => {
    const response = await fetch("/api/posts", {
      method: "POST",
      body: JSON.stringify(newPost),
    });
    return response.json();
  },
  onSuccess: () => {
    // Invalidate posts query
  },
}));
```

### Atom Families

```typescript
// atoms/entityAtoms.ts
import { atom } from "jotai";
import { atomFamily, selectAtom } from "jotai/utils";

// Normalized entities
export const postsMapAtom = atom<Record<string, Post>>({});
export const postIdsAtom = atom<string[]>([]);

// Atom family for individual posts
export const postAtomFamily = atomFamily((id: string) =>
  atom(
    (get) => get(postsMapAtom)[id],
    (get, set, update: Partial<Post>) => {
      const posts = get(postsMapAtom);
      if (posts[id]) {
        set(postsMapAtom, {
          ...posts,
          [id]: { ...posts[id], ...update },
        });
      }
    },
  ),
);

// Select atom for derived data
export const postTitlesAtom = selectAtom(postsMapAtom, (posts) =>
  Object.values(posts).map((p) => p.title),
);

// Parameterized derived atom
export const postsByAuthorAtomFamily = atomFamily((authorId: string) =>
  atom((get) => {
    const posts = get(postsMapAtom);
    return Object.values(posts).filter((p) => p.authorId === authorId);
  }),
);
```

### Atom Effects

```typescript
// atoms/effectAtoms.ts
import { atom } from "jotai";
import { atomEffect } from "jotai-effect";

// Atom with side effects
export const authEffectAtom = atomEffect((get, set) => {
  const token = get(tokenAtom);

  if (token) {
    // Set up token refresh interval
    const interval = setInterval(
      () => {
        refreshToken(token).then((newToken) => {
          set(tokenAtom, newToken);
        });
      },
      15 * 60 * 1000,
    ); // 15 minutes

    // Cleanup on unmount or token change
    return () => clearInterval(interval);
  }
});

// Logging effect
export const loggingEffectAtom = atomEffect((get) => {
  const user = get(userAtom);
  console.log("User changed:", user);
});

// Sync with localStorage
export const syncEffectAtom = atomEffect((get, set) => {
  const handleStorage = (e: StorageEvent) => {
    if (e.key === "user" && e.newValue) {
      set(userAtom, JSON.parse(e.newValue));
    }
  };

  window.addEventListener("storage", handleStorage);
  return () => window.removeEventListener("storage", handleStorage);
});
```

### Provider Pattern

```typescript
// providers/JotaiProvider.tsx
import { Provider, createStore } from 'jotai';
import { DevTools } from 'jotai-devtools';

const store = createStore();

// Hydrate from server
if (typeof window !== 'undefined') {
  const initialData = window.__INITIAL_STATE__;
  if (initialData?.user) {
    store.set(userAtom, initialData.user);
  }
}

export function JotaiProvider({ children }: { children: React.ReactNode }) {
  return (
    <Provider store={store}>
      <DevTools store={store} />
      {children}
    </Provider>
  );
}
```

---

## 4. TanStack Query (React Query)

### Query Client Configuration

```typescript
// lib/queryClient.ts
import { QueryClient } from "@tanstack/react-query";

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000, // 5 minutes
      gcTime: 30 * 60 * 1000, // 30 minutes (formerly cacheTime)
      retry: (failureCount, error) => {
        if (error.status === 404) return false;
        if (error.status === 401) return false;
        return failureCount < 3;
      },
      retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 30000),
      refetchOnWindowFocus: true,
      refetchOnReconnect: true,
    },
    mutations: {
      retry: 1,
      onError: (error) => {
        console.error("Mutation error:", error);
      },
    },
  },
});
```

### Custom Query Hooks

```typescript
// hooks/queries/usePosts.ts
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { postsApi } from "@/lib/api";

export const postKeys = {
  all: ["posts"] as const,
  lists: () => [...postKeys.all, "list"] as const,
  list: (filters: PostFilters) => [...postKeys.lists(), filters] as const,
  details: () => [...postKeys.all, "detail"] as const,
  detail: (id: string) => [...postKeys.details(), id] as const,
};

export function usePosts(filters: PostFilters = {}) {
  return useQuery({
    queryKey: postKeys.list(filters),
    queryFn: () => postsApi.getAll(filters),
    select: (data) => data.posts,
    placeholderData: (previousData) => previousData,
  });
}

export function usePost(id: string) {
  return useQuery({
    queryKey: postKeys.detail(id),
    queryFn: () => postsApi.getById(id),
    enabled: !!id,
  });
}

export function useCreatePost() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: postsApi.create,
    onMutate: async (newPost) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: postKeys.lists() });

      // Snapshot previous value
      const previousPosts = queryClient.getQueryData(postKeys.lists());

      // Optimistically update
      queryClient.setQueryData(postKeys.lists(), (old: Post[]) => [
        ...old,
        { ...newPost, id: "temp-id", createdAt: new Date().toISOString() },
      ]);

      return { previousPosts };
    },
    onError: (err, newPost, context) => {
      // Rollback on error
      queryClient.setQueryData(postKeys.lists(), context?.previousPosts);
    },
    onSettled: () => {
      // Refetch after mutation
      queryClient.invalidateQueries({ queryKey: postKeys.lists() });
    },
  });
}

export function useUpdatePost() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, ...data }: { id: string } & Partial<Post>) =>
      postsApi.update(id, data),
    onSuccess: (data, variables) => {
      // Update the individual post cache
      queryClient.setQueryData(postKeys.detail(variables.id), data);
      // Invalidate lists
      queryClient.invalidateQueries({ queryKey: postKeys.lists() });
    },
  });
}

export function useDeletePost() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: postsApi.delete,
    onMutate: async (deletedId) => {
      await queryClient.cancelQueries({ queryKey: postKeys.lists() });

      const previousPosts = queryClient.getQueryData(postKeys.lists());

      queryClient.setQueryData(postKeys.lists(), (old: Post[]) =>
        old.filter((post) => post.id !== deletedId),
      );

      return { previousPosts };
    },
    onError: (err, deletedId, context) => {
      queryClient.setQueryData(postKeys.lists(), context?.previousPosts);
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: postKeys.lists() });
    },
  });
}
```

### Infinite Queries

```typescript
// hooks/queries/useInfinitePosts.ts
import { useInfiniteQuery } from '@tanstack/react-query';

export function useInfinitePosts(filters: PostFilters = {}) {
  return useInfiniteQuery({
    queryKey: ['posts', 'infinite', filters],
    queryFn: ({ pageParam }) =>
      postsApi.getAll({ ...filters, cursor: pageParam }),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage) => lastPage.nextCursor,
    getPreviousPageParam: (firstPage) => firstPage.prevCursor,
    select: (data) => ({
      pages: data.pages.flatMap((page) => page.posts),
      pageParams: data.pageParams,
    }),
  });
}

// Usage in component
function PostList() {
  const {
    data,
    fetchNextPage,
    hasNextPage,
    isFetchingNextPage,
  } = useInfinitePosts();

  return (
    <div>
      {data?.pages.map((post) => (
        <PostCard key={post.id} post={post} />
      ))}
      {hasNextPage && (
        <button onClick={() => fetchNextPage()} disabled={isFetchingNextPage}>
          {isFetchingNextPage ? 'Loading...' : 'Load More'}
        </button>
      )}
    </div>
  );
}
```

### Prefetching Strategies

```typescript
// lib/prefetch.ts
import { queryClient } from "./queryClient";
import { postKeys, postsApi } from "./api";

// Prefetch on hover
export function prefetchPost(id: string) {
  queryClient.prefetchQuery({
    queryKey: postKeys.detail(id),
    queryFn: () => postsApi.getById(id),
    staleTime: 60 * 1000, // 1 minute
  });
}

// Prefetch in route loader (React Router)
export async function postsLoader() {
  return queryClient.ensureQueryData({
    queryKey: postKeys.lists(),
    queryFn: postsApi.getAll,
  });
}

// Server-side prefetch (Next.js)
// pages/posts/[id].tsx
export async function getServerSideProps({ params }) {
  await queryClient.prefetchQuery({
    queryKey: postKeys.detail(params.id),
    queryFn: () => postsApi.getById(params.id),
  });

  return {
    props: {
      dehydratedState: dehydrate(queryClient),
    },
  };
}
```

---

## 5. Recoil Patterns

### Atoms and Selectors

```typescript
// recoil/atoms.ts
import { atom, selector, selectorFamily, atomFamily } from "recoil";

// Basic atom
export const userState = atom<User | null>({
  key: "userState",
  default: null,
});

// Atom with effects
export const tokenState = atom<string | null>({
  key: "tokenState",
  default: null,
  effects: [
    ({ setSelf, onSet }) => {
      // Initialize from localStorage
      const savedToken = localStorage.getItem("token");
      if (savedToken) {
        setSelf(savedToken);
      }

      // Persist changes to localStorage
      onSet((newValue, _, isReset) => {
        if (isReset || newValue === null) {
          localStorage.removeItem("token");
        } else {
          localStorage.setItem("token", newValue);
        }
      });
    },
  ],
});

// Derived selector
export const isAuthenticatedState = selector<boolean>({
  key: "isAuthenticatedState",
  get: ({ get }) => !!get(tokenState),
});

// Async selector
export const currentUserState = selector<User | null>({
  key: "currentUserState",
  get: async ({ get }) => {
    const token = get(tokenState);
    if (!token) return null;

    const response = await fetch("/api/me", {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!response.ok) return null;
    return response.json();
  },
});

// Selector family (parameterized)
export const postByIdState = selectorFamily<Post | null, string>({
  key: "postByIdState",
  get:
    (id) =>
    async ({ get }) => {
      const response = await fetch(`/api/posts/${id}`);
      if (!response.ok) return null;
      return response.json();
    },
});

// Atom family for normalized data
export const postAtomFamily = atomFamily<Post | null, string>({
  key: "postAtomFamily",
  default: null,
});

export const postIdsState = atom<string[]>({
  key: "postIdsState",
  default: [],
});

// All posts selector combining atom family
export const allPostsState = selector<Post[]>({
  key: "allPostsState",
  get: ({ get }) => {
    const ids = get(postIdsState);
    return ids.map((id) => get(postAtomFamily(id))).filter(Boolean) as Post[];
  },
});
```

### Loadable Pattern

```typescript
// components/UserProfile.tsx
import { useRecoilValueLoadable } from 'recoil';
import { currentUserState } from '@/recoil/atoms';

function UserProfile() {
  const userLoadable = useRecoilValueLoadable(currentUserState);

  switch (userLoadable.state) {
    case 'loading':
      return <Skeleton />;
    case 'hasError':
      return <ErrorDisplay error={userLoadable.contents} />;
    case 'hasValue':
      return <UserCard user={userLoadable.contents} />;
  }
}
```

### Atom Effects for Sync

```typescript
// recoil/effects.ts
import { AtomEffect } from "recoil";

// WebSocket sync effect
export const websocketSyncEffect =
  <T>(channel: string): AtomEffect<T> =>
  ({ setSelf, onSet, trigger }) => {
    const socket = new WebSocket(`wss://api.example.com/${channel}`);

    socket.onmessage = (event) => {
      const data = JSON.parse(event.data);
      setSelf(data);
    };

    onSet((newValue) => {
      socket.send(JSON.stringify(newValue));
    });

    return () => socket.close();
  };

// URL sync effect
export const urlSyncEffect =
  (param: string): AtomEffect<string> =>
  ({ setSelf, onSet }) => {
    const params = new URLSearchParams(window.location.search);
    const value = params.get(param);
    if (value) setSelf(value);

    onSet((newValue) => {
      const url = new URL(window.location.href);
      if (newValue) {
        url.searchParams.set(param, newValue);
      } else {
        url.searchParams.delete(param);
      }
      window.history.replaceState({}, "", url);
    });
  };

// Usage
export const searchQueryState = atom<string>({
  key: "searchQueryState",
  default: "",
  effects: [urlSyncEffect("q")],
});
```

---

## 6. Context API Best Practices

### Optimized Context Pattern

```typescript
// context/AuthContext.tsx
import { createContext, useContext, useReducer, useMemo, useCallback } from 'react';

interface AuthState {
  user: User | null;
  token: string | null;
  isLoading: boolean;
}

type AuthAction =
  | { type: 'LOGIN_START' }
  | { type: 'LOGIN_SUCCESS'; payload: { user: User; token: string } }
  | { type: 'LOGIN_FAILURE' }
  | { type: 'LOGOUT' };

const authReducer = (state: AuthState, action: AuthAction): AuthState => {
  switch (action.type) {
    case 'LOGIN_START':
      return { ...state, isLoading: true };
    case 'LOGIN_SUCCESS':
      return {
        user: action.payload.user,
        token: action.payload.token,
        isLoading: false,
      };
    case 'LOGIN_FAILURE':
      return { ...state, isLoading: false };
    case 'LOGOUT':
      return { user: null, token: null, isLoading: false };
    default:
      return state;
  }
};

// Separate contexts for state and dispatch (prevents unnecessary re-renders)
const AuthStateContext = createContext<AuthState | null>(null);
const AuthDispatchContext = createContext<React.Dispatch<AuthAction> | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [state, dispatch] = useReducer(authReducer, {
    user: null,
    token: null,
    isLoading: false,
  });

  return (
    <AuthStateContext.Provider value={state}>
      <AuthDispatchContext.Provider value={dispatch}>
        {children}
      </AuthDispatchContext.Provider>
    </AuthStateContext.Provider>
  );
}

// Custom hooks with null checks
export function useAuthState() {
  const context = useContext(AuthStateContext);
  if (context === null) {
    throw new Error('useAuthState must be used within AuthProvider');
  }
  return context;
}

export function useAuthDispatch() {
  const context = useContext(AuthDispatchContext);
  if (context === null) {
    throw new Error('useAuthDispatch must be used within AuthProvider');
  }
  return context;
}

// Combined hook with memoized actions
export function useAuth() {
  const state = useAuthState();
  const dispatch = useAuthDispatch();

  const login = useCallback(
    async (email: string, password: string) => {
      dispatch({ type: 'LOGIN_START' });
      try {
        const { user, token } = await authApi.login({ email, password });
        dispatch({ type: 'LOGIN_SUCCESS', payload: { user, token } });
      } catch {
        dispatch({ type: 'LOGIN_FAILURE' });
        throw new Error('Login failed');
      }
    },
    [dispatch]
  );

  const logout = useCallback(() => {
    dispatch({ type: 'LOGOUT' });
  }, [dispatch]);

  return useMemo(
    () => ({
      ...state,
      login,
      logout,
      isAuthenticated: !!state.token,
    }),
    [state, login, logout]
  );
}
```

### Selector Context Pattern

```typescript
// context/SelectorContext.tsx
import { createContext, useContext, useSyncExternalStore, useCallback, useRef } from 'react';

type Listener = () => void;

function createStore<T>(initialState: T) {
  let state = initialState;
  const listeners = new Set<Listener>();

  return {
    getState: () => state,
    setState: (newState: T | ((prev: T) => T)) => {
      state = typeof newState === 'function'
        ? (newState as (prev: T) => T)(state)
        : newState;
      listeners.forEach((listener) => listener());
    },
    subscribe: (listener: Listener) => {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
  };
}

type Store<T> = ReturnType<typeof createStore<T>>;

const StoreContext = createContext<Store<AppState> | null>(null);

export function StoreProvider({ children }: { children: React.ReactNode }) {
  const storeRef = useRef<Store<AppState>>();
  if (!storeRef.current) {
    storeRef.current = createStore(initialState);
  }

  return (
    <StoreContext.Provider value={storeRef.current}>
      {children}
    </StoreContext.Provider>
  );
}

// Selector hook with subscription
export function useSelector<T, S>(selector: (state: T) => S): S {
  const store = useContext(StoreContext);
  if (!store) throw new Error('useSelector must be used within StoreProvider');

  return useSyncExternalStore(
    store.subscribe,
    () => selector(store.getState()),
    () => selector(store.getState())
  );
}

// Action hook
export function useDispatch() {
  const store = useContext(StoreContext);
  if (!store) throw new Error('useDispatch must be used within StoreProvider');
  return store.setState;
}
```

---

## Store Design Templates

### E-Commerce Store Template

```typescript
// stores/ecommerce.ts
import { create } from "zustand";
import { persist, devtools } from "zustand/middleware";
import { immer } from "zustand/middleware/immer";

interface CartItem {
  productId: string;
  quantity: number;
  price: number;
}

interface EcommerceState {
  cart: CartItem[];
  wishlist: string[];
  recentlyViewed: string[];

  // Cart actions
  addToCart: (productId: string, price: number, quantity?: number) => void;
  removeFromCart: (productId: string) => void;
  updateQuantity: (productId: string, quantity: number) => void;
  clearCart: () => void;

  // Wishlist actions
  addToWishlist: (productId: string) => void;
  removeFromWishlist: (productId: string) => void;

  // Recently viewed
  addToRecentlyViewed: (productId: string) => void;

  // Computed
  cartTotal: () => number;
  cartItemCount: () => number;
}

export const useEcommerceStore = create<EcommerceState>()(
  devtools(
    persist(
      immer((set, get) => ({
        cart: [],
        wishlist: [],
        recentlyViewed: [],

        addToCart: (productId, price, quantity = 1) =>
          set((state) => {
            const existing = state.cart.find(
              (item) => item.productId === productId,
            );
            if (existing) {
              existing.quantity += quantity;
            } else {
              state.cart.push({ productId, quantity, price });
            }
          }),

        removeFromCart: (productId) =>
          set((state) => {
            state.cart = state.cart.filter(
              (item) => item.productId !== productId,
            );
          }),

        updateQuantity: (productId, quantity) =>
          set((state) => {
            const item = state.cart.find(
              (item) => item.productId === productId,
            );
            if (item) {
              if (quantity <= 0) {
                state.cart = state.cart.filter(
                  (i) => i.productId !== productId,
                );
              } else {
                item.quantity = quantity;
              }
            }
          }),

        clearCart: () =>
          set((state) => {
            state.cart = [];
          }),

        addToWishlist: (productId) =>
          set((state) => {
            if (!state.wishlist.includes(productId)) {
              state.wishlist.push(productId);
            }
          }),

        removeFromWishlist: (productId) =>
          set((state) => {
            state.wishlist = state.wishlist.filter((id) => id !== productId);
          }),

        addToRecentlyViewed: (productId) =>
          set((state) => {
            state.recentlyViewed = [
              productId,
              ...state.recentlyViewed.filter((id) => id !== productId),
            ].slice(0, 10);
          }),

        cartTotal: () =>
          get().cart.reduce(
            (total, item) => total + item.price * item.quantity,
            0,
          ),

        cartItemCount: () =>
          get().cart.reduce((count, item) => count + item.quantity, 0),
      })),
      {
        name: "ecommerce-storage",
        partialize: (state) => ({ cart: state.cart, wishlist: state.wishlist }),
      },
    ),
    { name: "EcommerceStore" },
  ),
);
```

### Dashboard Store Template

```typescript
// stores/dashboard.ts
interface DashboardState {
  // Layout
  sidebarCollapsed: boolean;
  sidebarPinned: boolean;
  rightPanelOpen: boolean;
  rightPanelContent: "notifications" | "settings" | "help" | null;

  // Filters
  dateRange: { start: Date; end: Date };
  selectedMetrics: string[];
  groupBy: "day" | "week" | "month";

  // UI preferences
  theme: "light" | "dark" | "system";
  density: "compact" | "comfortable" | "spacious";

  // Actions
  toggleSidebar: () => void;
  toggleSidebarPin: () => void;
  openRightPanel: (content: DashboardState["rightPanelContent"]) => void;
  closeRightPanel: () => void;
  setDateRange: (range: { start: Date; end: Date }) => void;
  toggleMetric: (metric: string) => void;
  setGroupBy: (groupBy: DashboardState["groupBy"]) => void;
  setTheme: (theme: DashboardState["theme"]) => void;
  setDensity: (density: DashboardState["density"]) => void;
}

export const useDashboardStore = create<DashboardState>()(
  persist(
    (set) => ({
      sidebarCollapsed: false,
      sidebarPinned: true,
      rightPanelOpen: false,
      rightPanelContent: null,
      dateRange: {
        start: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000),
        end: new Date(),
      },
      selectedMetrics: ["revenue", "users", "orders"],
      groupBy: "day",
      theme: "system",
      density: "comfortable",

      toggleSidebar: () =>
        set((s) => ({ sidebarCollapsed: !s.sidebarCollapsed })),
      toggleSidebarPin: () => set((s) => ({ sidebarPinned: !s.sidebarPinned })),
      openRightPanel: (content) =>
        set({ rightPanelOpen: true, rightPanelContent: content }),
      closeRightPanel: () =>
        set({ rightPanelOpen: false, rightPanelContent: null }),
      setDateRange: (range) => set({ dateRange: range }),
      toggleMetric: (metric) =>
        set((s) => ({
          selectedMetrics: s.selectedMetrics.includes(metric)
            ? s.selectedMetrics.filter((m) => m !== metric)
            : [...s.selectedMetrics, metric],
        })),
      setGroupBy: (groupBy) => set({ groupBy }),
      setTheme: (theme) => set({ theme }),
      setDensity: (density) => set({ density }),
    }),
    { name: "dashboard-preferences" },
  ),
);
```

---

## Migration Patterns

### Redux to Zustand Migration

```typescript
// Step 1: Create equivalent Zustand store
// Before (Redux)
const authSlice = createSlice({
  name: "auth",
  initialState: { user: null, token: null },
  reducers: {
    setUser: (state, action) => {
      state.user = action.payload;
    },
    setToken: (state, action) => {
      state.token = action.payload;
    },
    logout: (state) => {
      state.user = null;
      state.token = null;
    },
  },
});

// After (Zustand)
const useAuthStore = create((set) => ({
  user: null,
  token: null,
  setUser: (user) => set({ user }),
  setToken: (token) => set({ token }),
  logout: () => set({ user: null, token: null }),
}));

// Step 2: Create adapter hook for gradual migration
function useAuth() {
  // Option A: Use Zustand directly
  const { user, token, setUser, logout } = useAuthStore();

  // Option B: Bridge to Redux (during migration)
  // const dispatch = useDispatch();
  // const { user, token } = useSelector((state) => state.auth);

  return { user, token, setUser, logout, isAuthenticated: !!token };
}

// Step 3: Replace usage one component at a time
// Step 4: Remove Redux dependencies after full migration
```

### Context to Zustand Migration

```typescript
// Before (Context)
const AuthContext = createContext();
function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [token, setToken] = useState(null);

  const login = async (credentials) => {
    const data = await authApi.login(credentials);
    setUser(data.user);
    setToken(data.token);
  };

  return (
    <AuthContext.Provider value={{ user, token, login }}>
      {children}
    </AuthContext.Provider>
  );
}

// After (Zustand) - No provider needed
const useAuthStore = create((set) => ({
  user: null,
  token: null,
  login: async (credentials) => {
    const data = await authApi.login(credentials);
    set({ user: data.user, token: data.token });
  },
}));

// Migration steps:
// 1. Create Zustand store with same interface
// 2. Create bridge hook that reads from both during migration
// 3. Update components one by one
// 4. Remove Context provider and related code
```

### Recoil to Jotai Migration

```typescript
// Recoil atoms
const userState = atom({ key: "user", default: null });
const isAuthenticatedState = selector({
  key: "isAuthenticated",
  get: ({ get }) => !!get(userState),
});

// Equivalent Jotai atoms
const userAtom = atom(null);
const isAuthenticatedAtom = atom((get) => !!get(userAtom));

// Recoil hooks -> Jotai hooks
// useRecoilState(userState) -> useAtom(userAtom)
// useRecoilValue(isAuthenticatedState) -> useAtomValue(isAuthenticatedAtom)
// useSetRecoilState(userState) -> useSetAtom(userAtom)
```

---

## Performance Optimization

### Selector Memoization

```typescript
// Zustand - Use shallow for object comparisons
import { shallow } from "zustand/shallow";

const { user, token } = useStore(
  (state) => ({ user: state.user, token: state.token }),
  shallow,
);

// Redux - Use createSelector for derived data
import { createSelector } from "@reduxjs/toolkit";

const selectPosts = (state) => state.posts.entities;
const selectFilter = (state) => state.posts.filter;

const selectFilteredPosts = createSelector(
  [selectPosts, selectFilter],
  (posts, filter) => Object.values(posts).filter((p) => p.category === filter),
);

// Jotai - Use selectAtom for partial subscriptions
import { selectAtom } from "jotai/utils";

const userNameAtom = selectAtom(userAtom, (user) => user?.name);
```

### Subscription Splitting

```typescript
// Bad - Re-renders on any state change
const state = useStore();

// Good - Only re-renders when specific values change
const user = useStore((state) => state.user);
const theme = useStore((state) => state.theme);

// Better - Combine related values with shallow
const auth = useStore(
  (state) => ({ user: state.user, token: state.token }),
  shallow,
);
```

### Batched Updates

```typescript
// Zustand - Multiple sets in one call
set((state) => ({
  user: newUser,
  token: newToken,
  lastLogin: new Date(),
}));

// Redux - Use batch for multiple dispatches
import { batch } from "react-redux";

batch(() => {
  dispatch(setUser(user));
  dispatch(setToken(token));
  dispatch(setLastLogin(new Date()));
});
```

### State Normalization

```typescript
// Normalized state shape
interface NormalizedState {
  posts: {
    byId: Record<string, Post>;
    allIds: string[];
  };
  users: {
    byId: Record<string, User>;
    allIds: string[];
  };
}

// Normalizing functions
function normalizeArray<T extends { id: string }>(array: T[]) {
  return {
    byId: Object.fromEntries(array.map((item) => [item.id, item])),
    allIds: array.map((item) => item.id),
  };
}

// Denormalizing for components
function denormalize(state: NormalizedState) {
  return state.posts.allIds.map((id) => ({
    ...state.posts.byId[id],
    author: state.users.byId[state.posts.byId[id].authorId],
  }));
}
```

---

## Testing Strategies

### Zustand Store Testing

```typescript
// store.test.ts
import { renderHook, act } from "@testing-library/react";
import { useAuthStore } from "./useAuthStore";

// Reset store between tests
beforeEach(() => {
  useAuthStore.setState({
    user: null,
    token: null,
    isAuthenticated: false,
  });
});

describe("useAuthStore", () => {
  it("should login user", () => {
    const { result } = renderHook(() => useAuthStore());

    act(() => {
      result.current.login({ id: "1", name: "Test" }, "token123");
    });

    expect(result.current.user).toEqual({ id: "1", name: "Test" });
    expect(result.current.token).toBe("token123");
    expect(result.current.isAuthenticated).toBe(true);
  });

  it("should logout user", () => {
    const { result } = renderHook(() => useAuthStore());

    act(() => {
      result.current.login({ id: "1", name: "Test" }, "token123");
    });

    act(() => {
      result.current.logout();
    });

    expect(result.current.user).toBeNull();
    expect(result.current.token).toBeNull();
  });
});
```

### Redux Store Testing

```typescript
// authSlice.test.ts
import authReducer, { login, logout, setCredentials } from "./authSlice";
import { configureStore } from "@reduxjs/toolkit";

describe("authSlice", () => {
  const initialState = { user: null, token: null, status: "idle", error: null };

  it("should handle setCredentials", () => {
    const user = { id: "1", email: "test@example.com", name: "Test" };
    const actual = authReducer(
      initialState,
      setCredentials({ user, token: "abc" }),
    );
    expect(actual.user).toEqual(user);
    expect(actual.token).toBe("abc");
  });

  it("should handle login.pending", () => {
    const actual = authReducer(initialState, { type: login.pending.type });
    expect(actual.status).toBe("loading");
  });

  it("should handle login.fulfilled", () => {
    const payload = { user: { id: "1" }, token: "token" };
    const actual = authReducer(
      { ...initialState, status: "loading" },
      { type: login.fulfilled.type, payload },
    );
    expect(actual.status).toBe("succeeded");
    expect(actual.user).toEqual(payload.user);
  });
});

// Integration test with real store
describe("auth integration", () => {
  let store: ReturnType<typeof configureStore>;

  beforeEach(() => {
    store = configureStore({ reducer: { auth: authReducer } });
  });

  it("should handle full login flow", async () => {
    // Mock API
    jest.spyOn(authApi, "login").mockResolvedValue({
      user: { id: "1", name: "Test" },
      token: "jwt-token",
    });

    await store.dispatch(login({ email: "test@test.com", password: "pass" }));

    const state = store.getState().auth;
    expect(state.user).toBeDefined();
    expect(state.token).toBe("jwt-token");
  });
});
```

### TanStack Query Testing

```typescript
// hooks/usePosts.test.tsx
import { renderHook, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { usePosts, useCreatePost } from './usePosts';

const createWrapper = () => {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false },
    },
  });
  return ({ children }) => (
    <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  );
};

describe('usePosts', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('should fetch posts', async () => {
    const mockPosts = [{ id: '1', title: 'Test Post' }];
    jest.spyOn(postsApi, 'getAll').mockResolvedValue({ posts: mockPosts });

    const { result } = renderHook(() => usePosts(), {
      wrapper: createWrapper(),
    });

    expect(result.current.isLoading).toBe(true);

    await waitFor(() => {
      expect(result.current.isSuccess).toBe(true);
    });

    expect(result.current.data).toEqual(mockPosts);
  });

  it('should create post with optimistic update', async () => {
    const newPost = { title: 'New Post', content: 'Content' };
    jest.spyOn(postsApi, 'create').mockResolvedValue({ id: '2', ...newPost });

    const { result } = renderHook(() => useCreatePost(), {
      wrapper: createWrapper(),
    });

    result.current.mutate(newPost);

    await waitFor(() => {
      expect(result.current.isSuccess).toBe(true);
    });

    expect(postsApi.create).toHaveBeenCalledWith(newPost);
  });
});
```

### Jotai Atom Testing

```typescript
// atoms/auth.test.ts
import { createStore } from 'jotai';
import { userAtom, isAuthenticatedAtom, tokenAtom } from './authAtoms';

describe('auth atoms', () => {
  let store: ReturnType<typeof createStore>;

  beforeEach(() => {
    store = createStore();
  });

  it('should derive isAuthenticated from token', () => {
    expect(store.get(isAuthenticatedAtom)).toBe(false);

    store.set(tokenAtom, 'some-token');
    expect(store.get(isAuthenticatedAtom)).toBe(true);

    store.set(tokenAtom, null);
    expect(store.get(isAuthenticatedAtom)).toBe(false);
  });

  it('should update user atom', () => {
    const user = { id: '1', name: 'Test User' };
    store.set(userAtom, user);
    expect(store.get(userAtom)).toEqual(user);
  });
});

// Component test with Jotai
import { render, screen } from '@testing-library/react';
import { Provider } from 'jotai';
import { useHydrateAtoms } from 'jotai/utils';

function HydrateAtoms({ initialValues, children }) {
  useHydrateAtoms(initialValues);
  return children;
}

function TestProvider({ initialValues, children }) {
  return (
    <Provider>
      <HydrateAtoms initialValues={initialValues}>{children}</HydrateAtoms>
    </Provider>
  );
}

it('should render user name', () => {
  render(
    <TestProvider initialValues={[[userAtom, { name: 'Test User' }]]}>
      <UserProfile />
    </TestProvider>
  );

  expect(screen.getByText('Test User')).toBeInTheDocument();
});
```

---

## Decision Matrix: Choosing a State Library

| Criteria         | Redux Toolkit  | Zustand   | Jotai     | TanStack Query | Recoil      |
| ---------------- | -------------- | --------- | --------- | -------------- | ----------- |
| Bundle size      | ~11KB          | ~1.5KB    | ~3KB      | ~13KB          | ~21KB       |
| Learning curve   | Medium         | Low       | Low       | Medium         | Medium      |
| Boilerplate      | Medium         | Low       | Low       | Medium         | Medium      |
| DevTools         | Excellent      | Good      | Good      | Excellent      | Good        |
| Server state     | RTK Query      | Manual    | Manual    | Native         | Manual      |
| React 18 support | Yes            | Yes       | Yes       | Yes            | Yes         |
| TypeScript       | Excellent      | Excellent | Excellent | Excellent      | Good        |
| Persistence      | Via middleware | Built-in  | Built-in  | Via options    | Via effects |
| SSR support      | Good           | Good      | Good      | Excellent      | Limited     |

### Recommendations

| Use Case                   | Recommended Library       |
| -------------------------- | ------------------------- |
| Large enterprise app       | Redux Toolkit + RTK Query |
| Small to medium app        | Zustand                   |
| Fine-grained reactivity    | Jotai                     |
| Server state only          | TanStack Query            |
| Complex async dependencies | Recoil                    |
| Just need global state     | Zustand or Jotai          |
| Need time-travel debugging | Redux Toolkit             |

---

## Example Usage

```
/agents/frontend/state-management-expert design global state architecture for e-commerce app
/agents/frontend/state-management-expert migrate from Redux to Zustand with step-by-step plan
/agents/frontend/state-management-expert implement TanStack Query for API caching
/agents/frontend/state-management-expert optimize re-renders in complex dashboard
/agents/frontend/state-management-expert set up Jotai atoms for form wizard
```
