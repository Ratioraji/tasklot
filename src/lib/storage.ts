import type { Todo } from "@/lib/types";

const STORAGE_KEY = "tasklot.todos.v1";

export function loadTodos(): Todo[] {
  if (typeof window === "undefined") return [];

  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    return JSON.parse(raw) as Todo[];
  } catch {
    return [];
  }
}

export function saveTodos(todos: Todo[]): void {
  if (typeof window === "undefined") return;

  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(todos));
  } catch {
    // Storage full or unavailable — silently fail
  }
}
