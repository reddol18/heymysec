import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart';
import 'package:mysec/utils/padding_column.dart';
import 'package:mysec/utils/padding_row.dart';

class SlotEditor extends StatefulWidget {
  final Map<dynamic, dynamic> result;
  final CalendarApi? calendar;
  final Function fn;
  final List<String> categories;
  final List<String> categorieIds;

  const SlotEditor(this.result, this.calendar, this.categories, this.categorieIds, this.fn);

  @override
  _SlotEditorState createState() => _SlotEditorState();
}

class _SlotEditorState extends State<SlotEditor> {
  DateTime? selectedDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String? selectedCategory;
  String? selectedCategoryId;
  TextEditingController titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedDate = widget.result["date"];
    startTime = widget.result["stime"];
    endTime = widget.result["etime"];
    selectedCategory = widget.result["category"];
    selectedCategoryId = widget.result["categoryId"] ?? "";
    titleController.text = widget.result["title"];
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PaddingColumn(
      paddingValue: 20.0,
      children: [
        PaddingRow(
          paddingValue: 10.0,
          children: [
            Text('날       짜  '),
            TextButton(
              onPressed: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setState(() {
                    selectedDate = picked;
                    widget.fn(selectedDate, startTime, endTime, selectedCategory, selectedCategoryId, titleController.text);
                  });
                }
              },
              child: Text(selectedDate?.toString().substring(0, 10) ?? '날짜 선택'),
            ),
          ],
        ),
        PaddingRow(
          paddingValue: 10.0,
          children: [
            Text('시       간  '),
            TextButton(
              onPressed: () async {
                final TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: startTime ?? TimeOfDay.now(),
                );
                if (picked != null) {
                  setState(() {
                    startTime = picked;
                    widget.fn(selectedDate, startTime, endTime, selectedCategory, selectedCategoryId, titleController.text);
                  });
                }
              },
              child: Text(startTime?.format(context) ?? '시작 시간 선택'),
            ),
            Text('  ~  '),
            TextButton(
              onPressed: () async {
                final TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: endTime ?? TimeOfDay.now(),
                );
                if (picked != null) {
                  setState(() {
                    endTime = picked;
                    widget.fn(selectedDate, startTime, endTime, selectedCategory, selectedCategoryId, titleController.text);
                  });
                }
              },
              child: Text(endTime?.format(context) ?? '끝 시간 선택'),
            ),
          ],
        ),
        PaddingRow(
          paddingValue: 10.0,
          children: [
            Text('카테고리  '),
            DropdownButton(
              value: selectedCategory,
              items: widget.categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedCategory = newValue;
                  selectedCategoryId = widget.categorieIds[widget.categories.indexOf(newValue!)];
                  widget.fn(selectedDate, startTime, endTime, selectedCategory, selectedCategoryId, titleController.text);
                });
              },
            ),
          ],
        ),
        PaddingRow(
          paddingValue: 10.0,
          children: [
            Text('제      목  '),
            Expanded(
              child: TextField(
                controller: titleController,
                onChanged: (String? newValue) {
                  setState(() {
                    widget.fn(selectedDate, startTime, endTime, selectedCategory, selectedCategoryId, newValue);
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
