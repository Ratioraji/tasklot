"use client";

import { TodoItem } from "@/components/todo-item";
import type { Todo, TodoFilter } from "@/lib/types";

const EMPTY_MESSAGES: Record<TodoFilter, string> = {
  all: "No todos yet. Add one above to get started.",
  active: "No active todos.",
  completed: "No completed todos.",
};

type Props = {
  todos: Todo[];
  filter: TodoFilter;
  onToggle: (id: string) => void;
  onRemove: (id: string) => void;
};

export function TodoList({ todos, filter, onToggle, onRemove }: Props) {
  if (todos.length === 0) {
    return (
      <p className="py-12 text-center text-sm text-gray-500">
        {EMPTY_MESSAGES[filter]}
      </p>
    );
  }

  return (
    <ul className="flex flex-col gap-2">
      {todos.map((todo) => (
        <TodoItem
          key={todo.id}
          todo={todo}
          onToggle={onToggle}
          onRemove={onRemove}
        />
      ))}
    </ul>
  );
}
