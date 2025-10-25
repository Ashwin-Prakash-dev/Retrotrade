import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';

class StockAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final Function(String symbol, String companyName) onStockSelected;
  final VoidCallback onSearch;
  final bool isLoading;

  const StockAutocomplete({
    super.key,
    required this.controller,
    required this.onStockSelected,
    required this.onSearch,
    this.isLoading = false,
  });

  @override
  State<StockAutocomplete> createState() => _StockAutocompleteState();
}

class _StockAutocompleteState extends State<StockAutocomplete> {
  final _focusNode = FocusNode();
  final _apiService = ApiService();
  
  List<StockSuggestion> _suggestions = [];
  bool _isLoadingSuggestions = false;
  bool _showSuggestions = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text.trim();
    
    if (text.isEmpty) {
      setState(() {
        _suggestions.clear();
        _showSuggestions = false;
      });
      return;
    }

    // Debounce the API calls
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchSuggestions(text);
    });
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      // Delay hiding suggestions to allow for selection
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          setState(() {
            _showSuggestions = false;
          });
        }
      });
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.length < 1) return;

    setState(() {
      _isLoadingSuggestions = true;
    });

    try {
      // Use the actual API service to fetch suggestions
      final suggestions = await _apiService.getStockSuggestions(query);
      
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _showSuggestions = suggestions.isNotEmpty;
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _suggestions.clear();
          _showSuggestions = false;
          _isLoadingSuggestions = false;
        });
      }
    }
  }

  void _selectSuggestion(StockSuggestion suggestion) {
    setState(() {
      _showSuggestions = false;
    });
    _focusNode.unfocus();
    widget.onStockSelected(suggestion.symbol, suggestion.companyName);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  labelText: 'Search Stock Symbol or Company Name',
                  hintText: 'e.g., AAPL, Apple, RELIANCE, TCS',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _isLoadingSuggestions
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: Padding(
                            padding: EdgeInsets.all(14.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : widget.controller.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                widget.controller.clear();
                                setState(() {
                                  _suggestions.clear();
                                  _showSuggestions = false;
                                });
                              },
                            )
                          : null,
                ),
                onSubmitted: (_) => widget.onSearch(),
                textInputAction: TextInputAction.search,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: widget.isLoading ? null : widget.onSearch,
              child: widget.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Search'),
            ),
          ],
        ),
        
        // Suggestions List
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 250),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return InkWell(
                  onTap: () => _selectSuggestion(suggestion),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: index < _suggestions.length - 1
                          ? Border(
                              bottom: BorderSide(
                                color: Colors.grey.shade300,
                                width: 0.5,
                              ),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: suggestion.matchType == 'symbol'
                                ? Colors.blue.shade100
                                : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            suggestion.symbol,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: suggestion.matchType == 'symbol'
                                  ? Colors.blue.shade800
                                  : Colors.green.shade800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                suggestion.companyName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (suggestion.matchType == 'company')
                                Text(
                                  'Symbol: ${suggestion.symbol}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}