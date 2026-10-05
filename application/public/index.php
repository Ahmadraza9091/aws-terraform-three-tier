<?php
declare(strict_types=1);

$configPath = getenv('APP_CONFIG_PATH') ?: '/etc/production-task-manager/config.json';
$config = json_decode((string) file_get_contents($configPath), true, 512, JSON_THROW_ON_ERROR);

function database(): PDO
{
    global $config;
    static $pdo;

    if (!$pdo) {
        $dsn = sprintf(
            'mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4',
            $config['db_host'],
            $config['db_port'],
            $config['db_name']
        );
        $pdo = new PDO($dsn, $config['db_username'], $config['db_password'], [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);
    }

    return $pdo;
}

function escape(string|int|null $value): string
{
    return htmlspecialchars((string) $value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function redirectHome(string $notice): never
{
    header('Location: /?notice=' . rawurlencode($notice), true, 303);
    exit;
}

function createCsrfToken(): string
{
    global $config;
    $payload = time() . '.' . bin2hex(random_bytes(16));
    return $payload . '.' . hash_hmac('sha256', $payload, $config['session_secret']);
}

function validCsrfToken(): bool
{
    global $config;
    $token = $_POST['csrf_token'] ?? null;
    if (!is_string($token)) {
        return false;
    }

    $parts = explode('.', $token);
    if (count($parts) !== 3 || !ctype_digit($parts[0])) {
        return false;
    }

    $issuedAt = (int) $parts[0];
    if ($issuedAt > time() + 60 || $issuedAt < time() - 7200) {
        return false;
    }

    $payload = $parts[0] . '.' . $parts[1];
    return hash_equals(hash_hmac('sha256', $payload, $config['session_secret']), $parts[2]);
}

function taskInput(): array
{
    $title = trim((string) ($_POST['title'] ?? ''));
    $description = trim((string) ($_POST['description'] ?? ''));
    $status = (string) ($_POST['status'] ?? 'todo');
    $dueDate = trim((string) ($_POST['due_date'] ?? ''));

    if ($title === '' || mb_strlen($title) > 120) {
        throw new InvalidArgumentException('Title must be between 1 and 120 characters.');
    }
    if (mb_strlen($description) > 2000) {
        throw new InvalidArgumentException('Description must be 2,000 characters or fewer.');
    }
    if (!in_array($status, ['todo', 'in_progress', 'done'], true)) {
        throw new InvalidArgumentException('Choose a valid task status.');
    }
    if ($dueDate !== '') {
        $date = DateTimeImmutable::createFromFormat('!Y-m-d', $dueDate);
        if (!$date || $date->format('Y-m-d') !== $dueDate) {
            throw new InvalidArgumentException('Enter a valid due date.');
        }
    }

    return [$title, $description, $status, $dueDate === '' ? null : $dueDate];
}

try {
    $pdo = database();
    $pdo->exec(
        "CREATE TABLE IF NOT EXISTS app_users (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
            username VARCHAR(100) NOT NULL UNIQUE,
            password_hash VARCHAR(255) NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"
    );
    $pdo->exec(
        "CREATE TABLE IF NOT EXISTS tasks (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
            user_id BIGINT UNSIGNED NOT NULL,
            title VARCHAR(120) NOT NULL,
            description VARCHAR(2000) NOT NULL DEFAULT '',
            status ENUM('todo', 'in_progress', 'done') NOT NULL DEFAULT 'todo',
            due_date DATE NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_tasks_user_updated (user_id, updated_at),
            CONSTRAINT fk_tasks_user FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"
    );
    $pdo->exec(
        "CREATE TABLE IF NOT EXISTS app_settings (
            setting_key VARCHAR(100) NOT NULL PRIMARY KEY,
            setting_value VARCHAR(255) NOT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"
    );

    $adminPasswordFingerprint = hash_hmac(
        'sha256',
        $config['admin_password'],
        $config['session_secret']
    );
    $pdo->beginTransaction();
    try {
        $pdo->exec(
            "INSERT IGNORE INTO app_settings (setting_key, setting_value)
             VALUES ('admin_password_fingerprint', '')"
        );
        $setting = $pdo->query(
            "SELECT setting_value FROM app_settings
             WHERE setting_key = 'admin_password_fingerprint' FOR UPDATE"
        )->fetchColumn();

        $admin = $pdo->prepare('SELECT id FROM app_users WHERE username = ? LIMIT 1');
        $admin->execute([$config['admin_username']]);
        $adminId = $admin->fetchColumn();
        if ($adminId === false) {
            $createAdmin = $pdo->prepare('INSERT INTO app_users (username, password_hash) VALUES (?, ?)');
            $createAdmin->execute([
                $config['admin_username'],
                password_hash($config['admin_password'], PASSWORD_DEFAULT),
            ]);
            $adminId = (int) $pdo->lastInsertId();
        } elseif (!hash_equals((string) $setting, $adminPasswordFingerprint)) {
            $updateAdmin = $pdo->prepare('UPDATE app_users SET password_hash = ? WHERE id = ?');
            $updateAdmin->execute([
                password_hash($config['admin_password'], PASSWORD_DEFAULT),
                $adminId,
            ]);
        }

        if (!hash_equals((string) $setting, $adminPasswordFingerprint)) {
            $updateSetting = $pdo->prepare(
                "UPDATE app_settings SET setting_value = ?
                 WHERE setting_key = 'admin_password_fingerprint'"
            );
            $updateSetting->execute([$adminPasswordFingerprint]);
        }
        $pdo->commit();
        $sharedOwnerId = (int) $adminId;
    } catch (Throwable $error) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        throw $error;
    }

    $csrfToken = createCsrfToken();
    $errorMessage = '';

    header('Cache-Control: no-store');
    header('X-Content-Type-Options: nosniff');
    header('X-Frame-Options: DENY');
    header('Referrer-Policy: no-referrer');
    header("Content-Security-Policy: default-src 'self'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'; object-src 'none'; script-src 'self'; style-src 'self'");

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        if (!validCsrfToken()) {
            $errorMessage = 'Your form expired. Reload the page and try again.';
        } else {
            $action = (string) ($_POST['action'] ?? '');
            try {
                if ($action === 'create' || $action === 'update') {
                    [$title, $description, $status, $dueDate] = taskInput();
                    if ($action === 'create') {
                        $statement = $pdo->prepare(
                            'INSERT INTO tasks (user_id, title, description, status, due_date) VALUES (?, ?, ?, ?, ?)'
                        );
                        $statement->execute([$sharedOwnerId, $title, $description, $status, $dueDate]);
                        redirectHome('added');
                    } else {
                        $id = filter_input(INPUT_POST, 'id', FILTER_VALIDATE_INT);
                        if (!$id || $id < 1) {
                            throw new InvalidArgumentException('Invalid task ID.');
                        }
                        $statement = $pdo->prepare(
                            'UPDATE tasks SET title = ?, description = ?, status = ?, due_date = ? WHERE id = ? AND user_id = ?'
                        );
                        $statement->execute([$title, $description, $status, $dueDate, $id, $sharedOwnerId]);
                        if ($statement->rowCount() === 0) {
                            $check = $pdo->prepare('SELECT id FROM tasks WHERE id = ? AND user_id = ?');
                            $check->execute([$id, $sharedOwnerId]);
                            if (!$check->fetch()) {
                                throw new RuntimeException('Task not found.');
                            }
                        }
                        redirectHome('updated');
                    }
                } elseif ($action === 'delete') {
                    $id = filter_input(INPUT_POST, 'id', FILTER_VALIDATE_INT);
                    if (!$id || $id < 1) {
                        throw new InvalidArgumentException('Invalid task ID.');
                    }
                    $statement = $pdo->prepare('DELETE FROM tasks WHERE id = ? AND user_id = ?');
                    $statement->execute([$id, $sharedOwnerId]);
                    if ($statement->rowCount() === 0) {
                        throw new RuntimeException('Task not found.');
                    }
                    redirectHome('deleted');
                } else {
                    throw new InvalidArgumentException('Unknown action.');
                }
            } catch (InvalidArgumentException|RuntimeException $error) {
                $errorMessage = $error->getMessage();
            }
        }
    }

    $flashMessage = [
        'added' => 'Task added.',
        'updated' => 'Task updated.',
        'deleted' => 'Task deleted.',
    ][(string) ($_GET['notice'] ?? '')] ?? '';
    $filter = (string) ($_GET['status'] ?? 'all');
    if (!in_array($filter, ['all', 'todo', 'in_progress', 'done'], true)) {
        $filter = 'all';
    }

    $tasks = [];
    $completeCount = 0;
    $statement = $pdo->prepare(
        'SELECT id, title, description, status, due_date, created_at, updated_at
         FROM tasks WHERE user_id = ? ORDER BY updated_at DESC, id DESC'
    );
    $statement->execute([$sharedOwnerId]);
    $tasks = $statement->fetchAll();
    $completeCount = count(array_filter($tasks, static fn(array $task): bool => $task['status'] === 'done'));
} catch (Throwable $error) {
    error_log('Task manager request failed: ' . $error->getMessage());
    http_response_code(503);
    header('Content-Type: text/plain; charset=utf-8');
    echo 'Task Manager is temporarily unavailable. Please try again later.';
    exit;
}

$serverIp = (string) ($_SERVER['SERVER_ADDR'] ?? '');
if (filter_var($serverIp, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4) === false) {
    $resolvedIp = gethostbyname(gethostname());
    $serverIp = filter_var($resolvedIp, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4) !== false
        ? $resolvedIp
        : 'Unavailable';
}
$serverHostname = gethostname() ?: 'Unknown';
?>
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="theme-color" content="#f5f7fb">
    <title>Taskboard — Production Task Manager</title>
    <link rel="stylesheet" href="/styles.css">
  </head>
  <body>
    <main class="shell">
      <header class="topbar">
        <a class="brand" href="/" aria-label="Taskboard home">
          <span class="brand-mark" aria-hidden="true">T</span>
          <span>Taskboard</span>
        </a>
      </header>

        <section aria-labelledby="page-title">
          <div class="page-heading">
            <div>
              <p class="eyebrow">SHARED WORKSPACE · PUBLIC ACCESS</p>
              <h1 id="page-title">Make room for <span>what matters.</span></h1>
              <p class="muted">Anyone with this link can view and manage these tasks.</p>
            </div>
            <div class="task-count"><?= $completeCount ?> of <?= count($tasks) ?> complete</div>
          </div>

          <?php if ($flashMessage !== ''): ?><p class="success-message" role="status"><?= escape($flashMessage) ?></p><?php endif; ?>
          <?php if ($errorMessage !== ''): ?><p class="form-message" role="alert"><?= escape($errorMessage) ?></p><?php endif; ?>

          <div class="workspace-grid">
            <form method="post" action="/" class="panel task-editor">
              <input type="hidden" name="csrf_token" value="<?= escape($csrfToken) ?>">
              <input type="hidden" name="action" value="create">
              <div class="editor-heading">
                <div class="icon-tile" aria-hidden="true">✦</div>
                <div><p class="eyebrow">TASK DETAILS</p><h2>Capture a task</h2></div>
              </div>
              <label for="task-title">What needs doing?</label>
              <input id="task-title" name="title" placeholder="e.g. Prepare the launch checklist" required maxlength="120">
              <label for="task-description">A few details <span class="optional">OPTIONAL</span></label>
              <textarea id="task-description" name="description" rows="4" placeholder="Add a note to your future self…" maxlength="2000"></textarea>
              <div class="form-row">
                <div>
                  <label for="task-status">Status</label>
                  <select id="task-status" name="status">
                    <option value="todo">To do</option>
                    <option value="in_progress">In progress</option>
                    <option value="done">Done</option>
                  </select>
                </div>
                <div>
                  <label for="task-due-date">Due date <span class="optional">OPTIONAL</span></label>
                  <input id="task-due-date" name="due_date" type="date">
                </div>
              </div>
              <button class="button button-primary button-full" type="submit">Add to my list <span aria-hidden="true">→</span></button>
            </form>

            <section class="task-list-section" aria-labelledby="list-title">
              <div class="list-heading">
                <div><p class="eyebrow">ONE THING AT A TIME</p><h2 id="list-title">Your task list</h2></div>
                <form method="get" action="/">
                  <select name="status" aria-label="Filter tasks by status">
                    <option value="all" <?= $filter === 'all' ? 'selected' : '' ?>>All tasks</option>
                    <option value="todo" <?= $filter === 'todo' ? 'selected' : '' ?>>To do</option>
                    <option value="in_progress" <?= $filter === 'in_progress' ? 'selected' : '' ?>>In progress</option>
                    <option value="done" <?= $filter === 'done' ? 'selected' : '' ?>>Done</option>
                  </select>
                  <button class="button button-quiet filter-button" type="submit">Filter</button>
                </form>
              </div>
              <div class="task-list">
                <?php
                $visibleTasks = array_filter($tasks, static fn(array $task): bool => $filter === 'all' || $task['status'] === $filter);
                if ($visibleTasks === []):
                ?>
                  <div class="empty-state"><?= $tasks === [] ? 'Your list is clear for now. Add a task when something comes to mind.' : 'No tasks match this filter.' ?></div>
                <?php else: foreach ($visibleTasks as $task): ?>
                  <article class="task-card">
                    <div class="task-card-top">
                      <h3 class="task-title"><?= escape($task['title']) ?></h3>
                      <span class="status-pill status-<?= escape($task['status']) ?>"><?= ['todo' => 'To do', 'in_progress' => 'In progress', 'done' => 'Done'][$task['status']] ?></span>
                    </div>
                    <p class="task-description"><?= $task['description'] !== '' ? nl2br(escape($task['description'])) : 'No extra details.' ?></p>
                    <div class="task-meta">
                      <span class="task-due"><?= $task['due_date'] ? 'Due ' . escape(date('M j, Y', strtotime($task['due_date']))) : 'No due date' ?></span>
                      <div class="task-actions">
                        <details>
                          <summary class="task-action">Edit</summary>
                          <form method="post" action="/" class="edit-form">
                            <input type="hidden" name="csrf_token" value="<?= escape($csrfToken) ?>">
                            <input type="hidden" name="action" value="update">
                            <input type="hidden" name="id" value="<?= (int) $task['id'] ?>">
                            <label>Title<input name="title" required maxlength="120" value="<?= escape($task['title']) ?>"></label>
                            <label>Description<textarea name="description" rows="3" maxlength="2000"><?= escape($task['description']) ?></textarea></label>
                            <label>Status<select name="status">
                              <option value="todo" <?= $task['status'] === 'todo' ? 'selected' : '' ?>>To do</option>
                              <option value="in_progress" <?= $task['status'] === 'in_progress' ? 'selected' : '' ?>>In progress</option>
                              <option value="done" <?= $task['status'] === 'done' ? 'selected' : '' ?>>Done</option>
                            </select></label>
                            <label>Due date<input name="due_date" type="date" value="<?= escape($task['due_date']) ?>"></label>
                            <button class="button button-primary" type="submit">Save changes</button>
                          </form>
                        </details>
                        <form method="post" action="/">
                          <input type="hidden" name="csrf_token" value="<?= escape($csrfToken) ?>">
                          <input type="hidden" name="action" value="delete">
                          <input type="hidden" name="id" value="<?= (int) $task['id'] ?>">
                          <button class="task-action delete" type="submit">Delete</button>
                        </form>
                      </div>
                    </div>
                  </article>
                <?php endforeach; endif; ?>
              </div>
            </section>
          </div>
        </section>
      <footer class="page-footer">
        <span class="footer-dot" aria-hidden="true"></span>
        <span>Shared task list — public access is enabled.</span>
        <span class="server-identity">Served by <?= escape($serverHostname) ?> · private IP <?= escape($serverIp) ?></span>
      </footer>
    </main>
  </body>
</html>
