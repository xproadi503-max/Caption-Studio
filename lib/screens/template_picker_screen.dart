import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/caption_templates.dart';
import '../models/caption_style.dart';
import '../providers/project_provider.dart';
import 'editor_preview_screen.dart';

class TemplatePickerScreen extends StatelessWidget {
  const TemplatePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final project = context.watch<ProjectProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Choose a caption style')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.95,
        ),
        itemCount: CaptionTemplates.all.length,
        itemBuilder: (context, index) {
          final template = CaptionTemplates.all[index];
          final selected = project.selectedTemplate.id == template.id;
          return _TemplateCard(
            template: template,
            selected: selected,
            onTap: () {
              project.setTemplate(template);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditorPreviewScreen()),
              );
            },
          );
        },
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final CaptionTemplate template;
  final bool selected;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.template,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.blueAccent : Colors.transparent,
            width: 2,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    Text(
                      'Sample ',
                      style: TextStyle(
                        color: template.textColor,
                        fontWeight: template.fontWeight,
                        fontSize: 16 * template.fontSize,
                      ),
                    ),
                    Text(
                      'Text',
                      style: TextStyle(
                        color: template.highlightColor,
                        fontWeight: template.fontWeight,
                        fontSize: 16 * template.fontSize,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              template.name,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
