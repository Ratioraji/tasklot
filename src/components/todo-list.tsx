"use client";

import { TodoItem } from "@/components/todo-item";
import type { Todo } from "@/lib/types";

type Props = {
  todos: Todo[];
  onToggle: (id: string) => void;
  onRemove: (id: string) => void;
};

export function TodoList({ todos, onToggle, onRemove }: Props) {
  if (todos.length === 0) {
    return (
      <p className="py-12 text-center text-sm text-gray-500">
        No todos yet. Add one above to get started.
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
