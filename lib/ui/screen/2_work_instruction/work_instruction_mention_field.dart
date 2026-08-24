import 'package:flutter/material.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/ui/widget/app_text_field.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/util/worker_skills_display.dart';

final _mentionTokenRe = RegExp(r'@([가-힣A-Za-z0-9._-]+)');

/// `@이름` 구간을 메신저처럼 강조하는 컨트롤러.
class MentionEditingController extends TextEditingController {
  MentionEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = value.text;
    if (text.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final cs = Theme.of(context).colorScheme;
    final mentionStyle = (style ?? const TextStyle()).copyWith(
      color: cs.primary,
      fontWeight: FontWeight.w800,
    );

    final children = <InlineSpan>[];
    var cursor = 0;
    for (final match in _mentionTokenRe.allMatches(text)) {
      if (match.start > cursor) {
        children.add(TextSpan(
          text: text.substring(cursor, match.start),
          style: style,
        ));
      }
      children.add(TextSpan(text: match.group(0), style: mentionStyle));
      cursor = match.end;
    }
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor), style: style));
    }
    return TextSpan(style: style, children: children);
  }
}

class WorkInstructionMentionQuery {
  const WorkInstructionMentionQuery({
    required this.start,
    required this.end,
    required this.query,
  });

  final int start;
  final int end;
  final String query;
}

WorkInstructionMentionQuery? mentionQueryAtCursor(String text, int cursor) {
  if (cursor < 0 || cursor > text.length) return null;
  final before = text.substring(0, cursor);
  final at = before.lastIndexOf('@');
  if (at < 0) return null;
  if (at > 0) {
    final prev = before[at - 1];
    if (RegExp(r'[가-힣A-Za-z0-9._-]').hasMatch(prev)) return null;
  }
  final typed = before.substring(at + 1);
  if (typed.contains(RegExp(r'\s'))) return null;
  return WorkInstructionMentionQuery(start: at, end: cursor, query: typed);
}

/// `@` 입력 시 등록 회원을 바로 고를 수 있는 작업지시 입력.
class WorkInstructionMentionField extends StatefulWidget {
  const WorkInstructionMentionField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.members,
    this.minLines = 6,
    this.maxLines = 10,
    this.hintText = '@로 사람을 태그하세요',
    this.onChanged,
  });

  final MentionEditingController controller;
  final FocusNode focusNode;
  final List<HumanModel> members;
  final int minLines;
  final int maxLines;
  final String hintText;
  final ValueChanged<String>? onChanged;

  @override
  State<WorkInstructionMentionField> createState() =>
      _WorkInstructionMentionFieldState();
}

class _WorkInstructionMentionFieldState
    extends State<WorkInstructionMentionField> {
  final _overlay = OverlayPortalController();
  final _link = LayerLink();
  WorkInstructionMentionQuery? _activeQuery;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant WorkInstructionMentionField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (!widget.focusNode.hasFocus) _hideOverlay();
  }

  void _onText() {
    if (!mounted) return;
    final selection = widget.controller.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      _hideOverlay();
      return;
    }
    final q = mentionQueryAtCursor(
      widget.controller.text,
      selection.baseOffset,
    );
    setState(() => _activeQuery = q);
    if (q == null || !widget.focusNode.hasFocus) {
      _hideOverlay();
      return;
    }
    if (!_overlay.isShowing) _overlay.show();
  }

  void _hideOverlay() {
    if (_overlay.isShowing) _overlay.hide();
    if (_activeQuery != null && mounted) {
      setState(() => _activeQuery = null);
    }
  }

  List<HumanModel> _filteredMembers() {
    final q = _activeQuery?.query.trim().toLowerCase() ?? '';
    final seen = <int>{};
    final out = <HumanModel>[];
    for (final h in widget.members) {
      final hid = h.hid;
      if (hid == null || hid <= 0 || h.hdelete != 0) continue;
      if (!seen.add(hid)) continue;
      if (q.isNotEmpty && !h.hname.toLowerCase().contains(q)) continue;
      out.add(h);
    }
    out.sort((a, b) => a.hname.compareTo(b.hname));
    return out.take(8).toList(growable: false);
  }

  void _insertMention(HumanModel human) {
    final q = _activeQuery;
    if (q == null) return;
    final text = widget.controller.text;
    final token = '@${human.hname} ';
    final next = text.replaceRange(q.start, q.end, token);
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: q.start + token.length),
    );
    _hideOverlay();
    widget.focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return OverlayPortal(
      controller: _overlay,
      overlayChildBuilder: (context) {
        final matches = _filteredMembers();
        return CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 8),
          child: Material(
            elevation: 8,
            color: cs.surface,
            shadowColor: cs.shadow.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(context.rs(14)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width - 48,
                maxHeight: 280,
                minWidth: 220,
              ),
              child: matches.isEmpty
                  ? Padding(
                      padding: EdgeInsets.all(context.rsi(14)),
                      child: Text(
                        '일치하는 회원이 없습니다',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.symmetric(vertical: context.rsi(6)),
                      shrinkWrap: true,
                      itemCount: matches.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: cs.outlineVariant.withValues(alpha: 0.4),
                      ),
                      itemBuilder: (context, i) {
                        final h = matches[i];
                        final skill = h.displayPrimarySpecialty?.trim();
                        final rank = resolveHumanSiteRank(h);
                        final sub = [
                          if (rank != null && rank.isNotEmpty) rank,
                          if (skill != null && skill.isNotEmpty) skill,
                        ].join('  ');
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: cs.primaryContainer,
                            foregroundColor: cs.onPrimaryContainer,
                            child: Text(
                              h.hname.isEmpty ? '?' : h.hname.substring(0, 1),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          title: Text(
                            h.hname,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: sub.isEmpty ? null : Text(sub),
                          onTap: () => _insertMention(h),
                        );
                      },
                    ),
            ),
          ),
        );
      },
      child: CompositedTransformTarget(
        link: _link,
        child: AppTextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            hintText: widget.hintText,
            filled: true,
            fillColor: cs.surfaceContainerLow.withValues(alpha: 0.65),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.rs(14)),
            ),
          ),
        ),
      ),
    );
  }
}
