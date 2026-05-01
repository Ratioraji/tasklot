"use client";

import { useCallback, useEffect, useState } from "react";

import { loadTodos, saveTodos } from "@/lib/storage";
import { createTodo, removeTodo, toggleTodo } from "@/lib/todo";
import type { Todo } from "@/lib/types";

export function useTodos() {
  const [todos, setTodos] = useState<Todo[]>([]);
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

  return { todos, addTodo, toggle, remove, isHydrated };
}
