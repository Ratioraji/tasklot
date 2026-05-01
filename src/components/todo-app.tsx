"use client";

import { TodoFooter } from "@/components/todo-footer";
import { TodoInput } from "@/components/todo-input";
import { TodoList } from "@/components/todo-list";
import { useTodos } from "@/hooks/use-todos";

export function TodoApp() {
  const {
    todos,
    visibleTodos,
    filter,
    setFilter,
    activeCount,
    hasCompleted,
    addTodo,
    toggle,
    remove,
    clearCompleted,
    isHydrated,
  } = useTodos();

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
      <TodoList
        todos={visibleTodos}
        filter={filter}
        onToggle={toggle}
        onRemove={remove}
      />
      {todos.length > 0 && (
        <TodoFooter
          activeCount={activeCount}
          hasCompleted={hasCompleted}
          filter={filter}
          onFilterChange={setFilter}
          onClearCompleted={clearCompleted}
        />
      )}
    </div>
  );
}
