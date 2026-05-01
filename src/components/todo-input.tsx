"use client";

import { useState } from "react";

type Props = {
  onAdd: (title: string) => void;
};

export function TodoInput({ onAdd }: Props) {
  const [value, setValue] = useState("");

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const trimmed = value.trim();
    if (!trimmed) return;
    onAdd(trimmed);
    setValue("");
  }

  return (
    <form onSubmit={handleSubmit} className="flex gap-2">
      <label htmlFor="todo-input" className="sr-only">
        New todo
      </label>
      <input
        id="todo-input"
        type="text"
        value={value}
        onChange={(e) => setValue(e.target.value)}
        placeholder="What needs to be done?"
        className="flex-1 rounded-lg border border-gray-300 px-4 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500/20"
      />
      <button
        type="submit"
        className="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:ring-offset-2"
      >
        Add
      </button>
    </form>
  );
}
