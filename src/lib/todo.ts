import type { Todo, TodoFilter } from "@/lib/types";

export function createTodo(title: string): Todo {
  return {
    id: crypto.randomUUID(),
    title,
    completed: false,
    createdAt: Date.now(),
  };
}

export function toggleTodo(todos: Todo[], id: string): Todo[] {
  return todos.map((todo) =>
    todo.id === id ? { ...todo, completed: !todo.completed } : todo
  );
}

export function removeTodo(todos: Todo[], id: string): Todo[] {
  return todos.filter((todo) => todo.id !== id);
}

export function filterTodos(todos: Todo[], filter: TodoFilter): Todo[] {
  switch (filter) {
    case "active":
      return todos.filter((todo) => !todo.completed);
    case "completed":
      return todos.filter((todo) => todo.completed);
    case "all":
      return todos;
  }
}
