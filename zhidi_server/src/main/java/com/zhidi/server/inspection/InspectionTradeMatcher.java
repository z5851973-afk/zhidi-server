package com.zhidi.server.inspection;

public final class InspectionTradeMatcher {

	private InspectionTradeMatcher() {
	}

	public static boolean matches(InspectionNode node, String bookingTrade) {
		return matchesName(node.getName(), bookingTrade);
	}

	public static boolean matchesName(String name, String bookingTrade) {
		String tradeLabel = normalizeLabel(bookingTrade);
		String nodeName = normalizeLabel(name);
		return nodeName.equals(tradeLabel + "验收") || nodeName.startsWith(tradeLabel);
	}

	private static String normalizeLabel(String value) {
		if (value == null || value.trim().isEmpty()) {
			return "工种";
		}
		String trimmed = value.trim();
		return switch (trimmed) {
			case "demolition", "拆除师傅", "拆除验收" -> "拆除";
			case "plumbing", "水电师傅", "水电验收" -> "水电";
			case "masonry", "泥瓦师傅", "泥瓦验收", "泥工", "泥工验收" -> "泥瓦";
			case "waterproof", "防水师傅", "防水验收" -> "防水";
			case "carpentry", "木工师傅", "木工验收" -> "木工";
			case "painting", "油漆师傅", "油漆验收" -> "油漆";
			case "installation", "安装师傅", "安装验收" -> "安装";
			case "cleaning", "保洁师傅", "保洁验收" -> "保洁";
			default -> {
				if (trimmed.endsWith("师傅")) {
					yield trimmed.substring(0, trimmed.length() - "师傅".length());
				}
				if (trimmed.endsWith("验收")) {
					yield trimmed.substring(0, trimmed.length() - "验收".length());
				}
				yield trimmed;
			}
		};
	}
}
