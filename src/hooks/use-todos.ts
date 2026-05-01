"use client";

import { useCallback, useEffect, useMemo, useState } from "react";

import { loadTodos, saveTodos } from "@/lib/storage";
import { createTodo, filterTodos, removeTodo, toggleTodo } from "@/lib/todo";
import type { Todo, TodoFilter } from "@/lib/types";

export function useTodos() {
  const [todos, setTodos] = useState<Todo[]>([]);
  const [filter, setFilter] = useState<TodoFilter>("all");
  const [isHydrated, setIsHydrated] = useState(false);

  useEffect(() => {
    setTodos(loadTodos());
    setIsHydrated(true);
  }, []);

  useEffect(() => {
    if (isHydrated) {
      saveTodos(todos);
    }
  }, [todos, isHydrated]);

  const addTodo = useCallback((title: string) => {
    const trimmed = title.trim();
    if (!trimmed) return;
    setTodos((prev) => [createTodo(trimmed), ...prev]);
  }, []);

  const toggle = useCallback((id: string) => {
    setTodos((prev) => toggleTodo(prev, id));
  }, []);

  const remove = useCallback((id: string) => {
    setTodos((prev) => removeTodo(prev, id));
  }, []);

  const clearCompleted = useCallback(() => {
    setTodos((prev) => prev.filter((todo) => !todo.completed));
  }, []);

  const visibleTodos = useMemo(
    () => filterTodos(todos, filter),
    [todos, filter],
  );

  const activeCount = useMemo(
    () => todos.filter((todo) => !todo.completed).length,
    [todos],
  );

  const hasCompleted = useMemo(
    () => todos.some((todo) => todo.completed),
    [todos],
  );

  return {
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
  };
}
