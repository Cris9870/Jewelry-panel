import { useState, useRef, useEffect } from 'react';
import { Search, X } from 'lucide-react';
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

const SearchableSelect = ({ 
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

  const selectedOption = options.find(opt => opt.id === value);

  const filteredOptions = options.filter(option => 
    option.label.toLowerCase().includes(search.toLowerCase()) ||
    (option.subLabel && option.subLabel.toLowerCase().includes(search.toLowerCase()))
  );

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
              filteredOptions.map(option => (
                <div
                  key={option.id}
                  className={`option ${option.id === value ? 'selected' : ''}`}
                  onClick={() => handleSelect(option.id)}
                >
                  <div>{option.label}</div>
                  {option.subLabel && (
                    <div className="option-sub-label">{option.subLabel}</div>
                  )}
                </div>
              ))
            )}
          </div>
        </div>
      )}
    </div>
  );
};

export default SearchableSelect;