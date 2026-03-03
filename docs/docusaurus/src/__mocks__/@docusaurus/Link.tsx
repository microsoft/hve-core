import React from 'react';

export default function Link({
  to,
  children,
  ...props
}: {
  to: string;
  children: React.ReactNode;
  [key: string]: unknown;
}) {
  return (
    <a href={to} {...props}>
      {children}
    </a>
  );
}
