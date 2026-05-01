"use client";

import { TodoInput } from "@/components/todo-input";
import { TodoList } from "@/components/todo-list";
import { useTodos } from "@/hooks/use-todos";

export function TodoApp() {
  const { todos, addTodo, toggle, remove, isHydrated } = useTodos();

  if (!isHydrated) {
    return (
      <div className="flex flex-col gap-6">
        <div className="h-10 animate-pulse rounded-lg bg-gray-100" />
        <div className="h-32 animate-pulse rounded-lg bg-gray-100" />
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-6">
      <TodoInput onAdd={addTodo} />
      <TodoList todos={todos} onToggle={toggle} onRemove={remove} />
    </div>
  );
}
