# 📦 Module 6: Modules and Reuse

## 🎯 Objectives

Choose a scope boundary, import a manifest-backed module, export only public
commands, provide comment-based help, and inject dependencies where useful.

## 💡 Concepts

Dot-sourcing loads another script into the caller's scope and is useful for
small controlled composition, but modules are the default reusable boundary.
A `.psm1` contains implementation; a `.psd1` manifest declares metadata and
exports. Keep helpers private. Scriptblock dependency injection lets a function
be tested without calling a network or system boundary.

## 📚 Files

- `01_module_boundary.ps1` - creates and imports a disposable module.
- `02_dependency_injection.ps1` - injects a data source scriptblock.

## ▶️ Run

```powershell
pwsh -NoProfile -File lessons/06_modules_and_reuse/01_module_boundary.ps1
pwsh -NoProfile -File lessons/06_modules_and_reuse/02_dependency_injection.ps1
```

## ⚠️ Common mistakes

- Exporting every helper by accident.
- Dot-sourcing untrusted or stateful scripts indiscriminately.
- Hard-coding an external dependency that a test cannot replace.

## ❓ Review questions

1. What does a module manifest add?
2. Why keep helpers private?
3. What boundary does an injected scriptblock create?
