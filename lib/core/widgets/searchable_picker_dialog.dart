import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../config/font_config.dart';
import 'basic_button.dart';
import 'basic_search_box.dart';

class SearchablePickerDialog<T> extends StatefulWidget {
  final String title;
  final List<String> items;
  final List<String>? suggestions;
  
  /// If provided, pre-selects these items
  final List<String> initialSelection;
  
  /// ✅ NEW: Toggle for Multi-Select Mode
  final bool multiSelect;

  const SearchablePickerDialog({
    super.key,
    required this.title,
    required this.items,
    this.suggestions,
    this.initialSelection = const [],
    this.multiSelect = false,
  });

  @override
  State<SearchablePickerDialog> createState() => _SearchablePickerDialogState();
}

class _SearchablePickerDialogState extends State<SearchablePickerDialog> {
  String _searchQuery = "";
  late Set<String> _selectedItems;

  @override
  void initState() {
    super.initState();
    _selectedItems = widget.initialSelection.toSet();
  }

  List<String> get _filteredItems {
    if (_searchQuery.isEmpty) return widget.items;
    return widget.items
        .where((item) => item.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  void _onItemTap(String item) {
    setState(() {
      if (widget.multiSelect) {
        // Toggle logic
        if (_selectedItems.contains(item)) {
          _selectedItems.remove(item);
        } else {
          _selectedItems.add(item);
        }
      } else {
        // Single select logic (replace)
        _selectedItems.clear();
        _selectedItems.add(item);
      }
    });
  }

  void _onConfirm() {
    if (_selectedItems.isEmpty) return;

    if (widget.multiSelect) {
      // Return List<String>
      Navigator.pop(context, _selectedItems.toList());
    } else {
      // Return String (Single)
      Navigator.pop(context, _selectedItems.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isNewItem = _searchQuery.isNotEmpty && 
        !widget.items.any((i) => i.toLowerCase() == _searchQuery.toLowerCase());

    final bool hasSuggestions = widget.suggestions != null && 
        widget.suggestions!.isNotEmpty && 
        _searchQuery.isEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9, 
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── PINNED HEADER ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.title, style: FontConfig.h3(context)),
                if (widget.multiSelect && _selectedItems.isNotEmpty)
                  Text(
                    "${_selectedItems.length} selected", 
                    style: const TextStyle(color: ThemeConfig.primaryGreen, fontWeight: FontWeight.bold)
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            BasicSearchBox(
              hintText: "Search or type new...",
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            const SizedBox(height: 12),

            // ─── SCROLLABLE MIDDLE ───
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50,
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: (hasSuggestions ? 1 : 0) + (isNewItem ? 1 : 0) + (_filteredItems.isEmpty ? 1 : _filteredItems.length),
                  itemBuilder: (context, index) {
                    
                    // A. Render Suggestions
                    if (hasSuggestions && index == 0) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            child: Text("Suggested:", style: FontConfig.caption(context)),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: widget.suggestions!.map((s) {
                              final isSelected = _selectedItems.contains(s);
                              return FilterChip(
                                label: Text(s),
                                selected: isSelected,
                                onSelected: (v) {
                                  _onItemTap(s);
                                  // Don't clear search query in multi-select for rapid picking
                                  if (!widget.multiSelect) _searchQuery = "";
                                },
                                backgroundColor: Colors.white,
                                selectedColor: ThemeConfig.primaryGreen.withValues(alpha: 0.2),
                                labelStyle: TextStyle(
                                  color: isSelected ? ThemeConfig.primaryGreen : Colors.black87,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                checkmarkColor: ThemeConfig.primaryGreen,
                                side: BorderSide(color: Colors.grey.shade300),
                              );
                            }).toList(),
                          ),
                          const Divider(height: 24),
                        ],
                      );
                    }

                    int effectiveIndex = hasSuggestions ? index - 1 : index;

                    // B. Render "Create New"
                    if (isNewItem && effectiveIndex == 0) {
                      return ListTile(
                        onTap: () => _onItemTap(_searchQuery),
                        leading: const Icon(Icons.add_circle, color: Colors.blue),
                        title: Text('Use "$_searchQuery" as new', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                        tileColor: Colors.blue.withValues(alpha: 0.05),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      );
                    }

                    if (isNewItem) effectiveIndex--;

                    // C. Render "No Items"
                    if (_filteredItems.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(30.0),
                        child: Center(child: Text("No matching variants found.")),
                      );
                    }

                    // D. Render Standard List Item
                    final item = _filteredItems[effectiveIndex];
                    final isSelected = _selectedItems.contains(item);

                    return Material(
                      color: isSelected ? ThemeConfig.primaryGreen.withValues(alpha: 0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: ListTile(
                        onTap: () => _onItemTap(item),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        title: Text(
                          item,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? ThemeConfig.primaryGreen : Colors.black87,
                          ),
                        ),
                        // ✅ Use Checkbox for multi, simple Check icon for single
                        trailing: widget.multiSelect
                            ? Checkbox(
                                value: isSelected, 
                                activeColor: ThemeConfig.primaryGreen,
                                onChanged: (v) => _onItemTap(item)
                              )
                            : (isSelected ? const Icon(Icons.check_circle, color: ThemeConfig.primaryGreen) : null),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ─── PINNED FOOTER ───
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                BasicButton(
                  label: "Cancel",
                  type: AppButtonType.secondary,
                  onPressed: () => Navigator.pop(context),
                  fullWidth: false,
                ),
                const SizedBox(width: 12),
                BasicButton(
                  label: "Confirm",
                  type: AppButtonType.primary,
                  onPressed: _selectedItems.isEmpty ? null : _onConfirm,
                  fullWidth: false,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}