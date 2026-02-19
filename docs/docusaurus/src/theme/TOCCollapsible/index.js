import React from 'react';
import TOCCollapsible from '@theme-original/TOCCollapsible';

export default function TOCCollapsibleWrapper(props) {
  return (
    <div className="ms-learn-toc">
      <p style={{
        fontSize: '0.875rem',
        fontWeight: 600,
        color: 'var(--ms-learn-text-subtle)',
        marginBottom: '0.5rem',
        textTransform: 'uppercase',
        letterSpacing: '0.05em',
      }}>
        In this article
      </p>
      <TOCCollapsible {...props} />
    </div>
  );
}
