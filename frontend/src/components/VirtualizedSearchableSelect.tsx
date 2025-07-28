import { useState, useRef, useEffect, useMemo, memo } from 'react';
import { Search, X } from 'lucide-react';
import { FixedSizeList as List } from 'react-window';
import './SearchableSelect.css';

interface Option {
  id: number;
  label: string;
  subLabel?: string;
}

interface SearchableSelectProps {
  options: Option[];
  value: number | null;
  onChange: (value: number | null) => void;
  placeholder?: string;
  label?: string;
  required?: boolean;
}

// Altura de cada item en la lista
const ITEM_HEIGHT = 50;
// Altura máxima de la lista
const LIST_HEIGHT = 300;

// Componente memoizado para cada opción
const OptionItem = memo(({ 
  data, 
  index, 
  style 
}: { 
  data: { 
    options: Option[], 
    selectedId: number | null, 
    onSelect: (id: number) => void 
  }, 
  index: number, 
  style: React.CSSProperties 
}) => {
  const option = data.options[index];
  const isSelected = option.id === data.selectedId;
  
  return (
    <div
      style={style}
      className={`option ${isSelected ? 'selected' : ''}`}
      onClick={() => data.onSelect(option.id)}
    >
      <div>{option.label}</div>
      {option.subLabel && (
        <div className="option-sub-label">{option.subLabel}</div>
      )}
    </div>
  );
});

OptionItem.displayName = 'OptionItem';

const VirtualizedSearchableSelect = memo(({ 
  options, 
  value, 
  onChange, 
  placeholder = "Buscar...",
  label,
  required = false
}: SearchableSelectProps) => {
  const [isOpen, setIsOpen] = useState(false);
  const [search, setSearch] = useState('');
  const dropdownRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  const selectedOption = useMemo(
    () => options.find(opt => opt.id === value),
    [options, value]
  );

  // Filtrado optimizado con useMemo
  const filteredOptions = useMemo(() => {
    if (!search) return options;
    
    const searchLower = search.toLowerCase();
    return options.filter(option => 
      option.label.toLowerCase().includes(searchLower) ||
      (option.subLabel && option.subLabel.toLowerCase().includes(searchLower))
    );
  }, [options, search]);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const handleSelect = (optionId: number) => {
    onChange(optionId);
    setIsOpen(false);
    setSearch('');
  };

  const handleClear = (e: React.MouseEvent) => {
    e.stopPropagation();
    onChange(null);
    setSearch('');
  };

  // Datos para react-window
  const itemData = {
    options: filteredOptions,
    selectedId: value,
    onSelect: handleSelect
  };

  // Calcular altura de la lista
  const listHeight = Math.min(
    filteredOptions.length * ITEM_HEIGHT,
    LIST_HEIGHT
  );

  return (
    <div className="searchable-select" ref={dropdownRef}>
      {label && <label>{label} {required && '*'}</label>}
      
      <div className="select-control" onClick={() => setIsOpen(!isOpen)}>
        <div className="select-value">
          {selectedOption ? (
            <div>
              <span>{selectedOption.label}</span>
              {selectedOption.subLabel && (
                <span className="sub-label"> - {selectedOption.subLabel}</span>
              )}
            </div>
          ) : (
            <span className="placeholder">{placeholder}</span>
          )}
        </div>
        
        <div className="select-actions">
          {value && (
            <button 
              type="button"
              className="clear-btn"
              onClick={handleClear}
            >
              <X size={16} />
            </button>
          )}
          <Search size={16} className="search-icon" />
        </div>
      </div>

      {isOpen && (
        <div className="select-dropdown">
          <div className="search-input-wrapper">
            <Search size={16} />
            <input
              ref={inputRef}
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Buscar..."
              className="search-input"
              autoFocus
            />
          </div>

          <div className="options-list">
            {filteredOptions.length === 0 ? (
              <div className="no-options">No se encontraron resultados</div>
            ) : (
              <List
                height={listHeight}
                itemCount={filteredOptions.length}
                itemSize={ITEM_HEIGHT}
                width="100%"
                itemData={itemData}
              >
                {OptionItem}
              </List>
            )}
          </div>
        </div>
      )}
    </div>
  );
});

VirtualizedSearchableSelect.displayName = 'VirtualizedSearchableSelect';

export default VirtualizedSearchableSelect;