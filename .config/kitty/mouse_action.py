def main(args):
    pass

def handle_result(args, answer, target_window_id, boss):
    w = boss.window_id_map.get(target_window_id)
    if w is None:
        return
    if w.has_selection():
        w.copy_to_clipboard()
        w.clear_selection()
    else:
        boss.paste_from_clipboard()

handle_result.no_ui = True
