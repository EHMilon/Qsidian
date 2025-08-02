import 'package:flutter/material.dart';

String getFileDisplayName(String fileUri) {
  try {
    final Uri parsedUri = Uri.parse(fileUri);
    if (parsedUri.pathSegments.isNotEmpty) {
      final String lastSegment = parsedUri.pathSegments.last;
      String decoded = Uri.decodeComponent(lastSegment);
      // Remove .md extension for display
      if (decoded.endsWith('.md')) {
        decoded = decoded.substring(0, decoded.length - 3);
      }
      return decoded;
    }
  } catch (e) {
    final int lastSlashIndex = fileUri.lastIndexOf('/');
    if (lastSlashIndex != -1 && lastSlashIndex < fileUri.length - 1) {
      String filename = fileUri.substring(lastSlashIndex + 1);
      try {
        filename = Uri.decodeComponent(filename);
        if (filename.endsWith('.md')) {
          filename = filename.substring(0, filename.length - 3);
        }
        return filename;
      } catch (e2) {
        return filename;
      }
    }
  }
  return "Unknown File";
}

String getDisplayPath(String uri) {
  try {
    final int lastSlashIndex = uri.lastIndexOf('/');
    if (lastSlashIndex != -1 && lastSlashIndex < uri.length - 1) {
      final String filename = uri.substring(lastSlashIndex + 1);
      try {
        return Uri.decodeComponent(filename);
      } catch (e) {
        return filename;
      }
    }
    return "";
  } catch (e) {
    return "";
  }
}

String getVaultDisplayName(String? uriString) {
  if (uriString == null) return "No Vault Selected";
  try {
    final Uri uri = Uri.parse(uriString);
    String path = Uri.decodeComponent(uri.path);
    List<String> segments = path.split('/').where((s) => s.isNotEmpty).toList();

    for (String segment in segments) {
      if (segment.contains(':')) {
        return segment.split(':').last;
      }
    }
    return segments.isNotEmpty ? segments.last : "Selected Vault";
  } catch (e) {
    return "Selected Vault";
  }
}

String getRelativePath(String fileUri, String? vaultUri) {
  try {
    final String vaultUriString = vaultUri ?? '';
    final Uri fileParsedUri = Uri.parse(fileUri);
    final Uri vaultParsedUri = Uri.parse(vaultUriString);

    List<String> fileSegments = fileParsedUri.pathSegments
        .map((s) => Uri.decodeComponent(s))
        .toList();
    List<String> vaultSegments = vaultParsedUri.pathSegments
        .map((s) => Uri.decodeComponent(s))
        .toList();

    int commonPrefixEndIndex = 0;
    for (int i = 0; i < fileSegments.length && i < vaultSegments.length; i++) {
      if (fileSegments[i] == vaultSegments[i]) {
        commonPrefixEndIndex = i + 1;
      } else {
        break;
      }
    }

    List<String> relativeSegments = fileSegments.sublist(commonPrefixEndIndex);

    if (relativeSegments.isNotEmpty) {
      relativeSegments = relativeSegments.sublist(
        0,
        relativeSegments.length - 1,
      );
    }

    final String directory = relativeSegments.join('/');
    return directory.isEmpty ? "Root" : directory;
  } catch (e) {
    return "Root";
  }
}

Widget buildBreadcrumb(
  BuildContext context,
  String? currentFolderUri,
  String? vaultUri,
  List<String> navigationStack,
  String Function() getCurrentFolderName, // Pass as a function
) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  if (currentFolderUri == null || vaultUri == null) {
    return Text(
      "Vault",
      style: theme.textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    );
  }

  if (currentFolderUri == vaultUri) {
    return Text(
      "Root",
      style: theme.textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    );
  }

  List<String> breadcrumbParts = [];
  breadcrumbParts.add("Root");

  for (String folderUri in navigationStack) {
    if (folderUri != vaultUri) {
      try {
        final Uri uri = Uri.parse(folderUri);
        if (uri.pathSegments.isNotEmpty) {
          breadcrumbParts.add(Uri.decodeComponent(uri.pathSegments.last));
        }
      } catch (e) {
        // Skip invalid URIs
      }
    }
  }

  breadcrumbParts.add(getCurrentFolderName());

  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (int i = 0; i < breadcrumbParts.length; i++) ...[
          if (i > 0)
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          Text(
            breadcrumbParts[i],
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: i == breadcrumbParts.length - 1
                  ? FontWeight.w500
                  : FontWeight.normal,
            ),
          ),
        ],
      ],
    ),
  );
}

String getCurrentFolderNameUtil(String? currentFolderUri, String? vaultUri) {
  if (currentFolderUri == null || vaultUri == null) {
    return "Vault";
  }

  if (currentFolderUri == vaultUri) {
    return "Root";
  }

  try {
    final Uri uri = Uri.parse(currentFolderUri);
    if (uri.pathSegments.isNotEmpty) {
      return Uri.decodeComponent(uri.pathSegments.last);
    }
  } catch (e) {
    final int lastSlashIndex = currentFolderUri.lastIndexOf('/');
    if (lastSlashIndex != -1 && lastSlashIndex < currentFolderUri.length - 1) {
      try {
        return Uri.decodeComponent(
          currentFolderUri.substring(lastSlashIndex + 1),
        );
      } catch (e2) {
        return currentFolderUri.substring(lastSlashIndex + 1);
      }
    }
  }

  return "Folder";
}
