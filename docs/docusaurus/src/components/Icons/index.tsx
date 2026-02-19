import React from 'react';

export function GettingStartedIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 64 64" className={className} aria-hidden="true">
      <circle cx="32" cy="28" r="20" fill="#0078d4" />
      <path d="M28 20l12 8-12 8z" fill="#fff" />
      <rect x="20" y="52" width="24" height="4" rx="2" fill="#0078d4" opacity="0.4" />
    </svg>
  );
}

export function AgentsPromptsIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 64 64" className={className} aria-hidden="true">
      <rect x="8" y="8" width="36" height="28" rx="4" fill="#7719aa" />
      <circle cx="20" cy="22" r="2.5" fill="#fff" />
      <circle cx="28" cy="22" r="2.5" fill="#fff" />
      <circle cx="36" cy="22" r="2.5" fill="#fff" />
      <path d="M16 36l-4 8h12z" fill="#7719aa" opacity="0.7" />
      <rect x="28" y="24" width="28" height="22" rx="4" fill="#e8740c" />
      <rect x="34" y="31" width="16" height="2" rx="1" fill="#fff" />
      <rect x="34" y="37" width="12" height="2" rx="1" fill="#fff" />
      <path d="M48 46l6 8h-12z" fill="#e8740c" opacity="0.7" />
    </svg>
  );
}

export function InstructionsSkillsIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 64 64" className={className} aria-hidden="true">
      <path d="M12 4h28v48H12z" fill="#0078d4" />
      <path d="M16 8h28v48H16z" fill="#005ba1" />
      <rect x="22" y="16" width="16" height="2" rx="1" fill="#fff" />
      <rect x="22" y="22" width="12" height="2" rx="1" fill="#fff" opacity="0.7" />
      <rect x="22" y="28" width="16" height="2" rx="1" fill="#fff" />
      <rect x="22" y="34" width="10" height="2" rx="1" fill="#fff" opacity="0.7" />
      <circle cx="46" cy="46" r="14" fill="#e8740c" />
      <path d="M40 46l4 4 8-8" fill="none" stroke="#fff" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

export function WorkflowsIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 64 64" className={className} aria-hidden="true">
      <circle cx="12" cy="32" r="8" fill="#0078d4" />
      <circle cx="52" cy="32" r="8" fill="#0078d4" />
      <circle cx="32" cy="12" r="8" fill="#7719aa" />
      <circle cx="32" cy="52" r="8" fill="#e8740c" />
      <path d="M20 28l8-12M20 36l8 12" fill="none" stroke="#505050" strokeWidth="2" />
      <path d="M40 16l8 12M40 48l8-12" fill="none" stroke="#505050" strokeWidth="2" />
    </svg>
  );
}

export function DesignThinkingIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 64 64" className={className} aria-hidden="true">
      <path d="M32 4C20 4 12 14 12 24c0 7 3 11 7 15v5h26v-5c4-4 7-8 7-15C52 14 44 4 32 4z" fill="#e8740c" />
      <path d="M32 4C20 4 12 14 12 24c0 7 3 11 7 15v5h13V4z" fill="#e8740c" opacity="0.8" />
      <rect x="22" y="48" width="20" height="4" rx="2" fill="#505050" />
      <rect x="24" y="54" width="16" height="4" rx="2" fill="#505050" opacity="0.6" />
      <line x1="32" y1="16" x2="32" y2="30" stroke="#fff" strokeWidth="2.5" strokeLinecap="round" />
      <circle cx="32" cy="34" r="2" fill="#fff" />
    </svg>
  );
}

export function TemplatesExamplesIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 64 64" className={className} aria-hidden="true">
      <rect x="4" y="4" width="26" height="26" rx="3" fill="#0078d4" />
      <rect x="34" y="4" width="26" height="26" rx="3" fill="#7719aa" />
      <rect x="4" y="34" width="26" height="26" rx="3" fill="#e8740c" />
      <rect x="34" y="34" width="26" height="26" rx="3" fill="#005ba1" />
      <rect x="10" y="10" width="14" height="2" rx="1" fill="#fff" opacity="0.6" />
      <rect x="10" y="16" width="10" height="2" rx="1" fill="#fff" opacity="0.4" />
      <rect x="40" y="10" width="14" height="2" rx="1" fill="#fff" opacity="0.6" />
      <rect x="40" y="16" width="10" height="2" rx="1" fill="#fff" opacity="0.4" />
      <rect x="10" y="40" width="14" height="2" rx="1" fill="#fff" opacity="0.6" />
      <rect x="10" y="46" width="10" height="2" rx="1" fill="#fff" opacity="0.4" />
      <rect x="40" y="40" width="14" height="2" rx="1" fill="#fff" opacity="0.6" />
      <rect x="40" y="46" width="10" height="2" rx="1" fill="#fff" opacity="0.4" />
    </svg>
  );
}
