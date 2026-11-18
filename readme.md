# `regscript`

`regscript` is a WIP register-based bytecode VM for a subset of the Haxe scripting language.

Written with the hopes of fully supporting scripts interpreted by [hscript-improved](https://github.com/CodenameCrew/hscript-improved).

---

> [!NOTE]
> When compiled with `-D hscriptPos` you'll get useful error reporting.

```
lexer -> preprocessor -> parser -> type checker -> compiler -> optimizer -> register vm
```

> [!IMPORTANT]
> Unit testing depends on [`utest`](https://lib.haxe.org/p/utest/)

---

For todo, refer to [todo.md](./todo.md)